# Cornerman — Engineering Plan: Background Execution & Performance

**Repo:** `~/Workfolder/Cornerman`
**For:** Claude Code execution
**Goal:** Make the timer (a) survive backgrounding like Spotify/native stopwatch, and (b) be fast and light enough for low-end devices.

---

## How to use this document

Run Claude Code from the repo root. Start with:

> Read this plan in full. Then read the existing codebase and produce a written gap analysis against Phase 0 before changing any code. Do not start implementing until I approve the gap analysis.

Then work through the phases **in order**. Each phase has explicit acceptance criteria — do not advance until they pass. Phases 1 and 2 are the substance; Phase 3 is measurement; Phase 4 is polish.

---

## Phase 0 — Audit the existing code (no changes yet)

Read the current implementation and report:

1. **How is time currently tracked?** Specifically: does the timer decrement a counter on each tick, or does it derive remaining time from an absolute timestamp? (This is the single most important question — the answer determines how much of Phase 1 is a rewrite vs. a refactor.)
2. **What rebuilds on each tick?** Trace from the ticker to the widget tree. How many widgets rebuild per tick? Is the whole screen rebuilding, or just the digits?
3. **How is audio initialized?** Are players preloaded once, or constructed per cue?
4. **Current lifecycle handling** — is there any `AppLifecycleState` handling at all today?
5. **Current app size** — run `flutter build apk --analyze-size --target-platform android-arm64` and report the breakdown.

Output a short gap analysis. Flag anything in the existing code that conflicts with the architecture below.

---

## Phase 1 — Re-architect the timer as a pure function of wall-clock time

This is the foundation for everything else. **Do this before touching background execution.**

### The core idea

The timer engine must hold **no mutable countdown state**. Its entire state is:

```dart
class WorkoutState {
  final TimerConfig config;
  final DateTime? startedAt;        // null = idle
  final Duration pausedOffset;      // total time spent paused
  final DateTime? pausedAt;         // null = not currently paused
  final int skipOffsetMs;           // accumulated manual skips
}
```

Everything else — current phase, current round, remaining time, progress fraction — is **derived** by a pure function:

```dart
WorkoutSnapshot resolve(WorkoutState state, DateTime now)
```

`resolve()` must be a pure, synchronous, allocation-light function with no side effects. It computes elapsed wall-clock time, subtracts paused time and skip offsets, then walks the phase schedule to determine where you are.

### Why this matters

- **Zero drift.** Not "low drift" — mathematically zero, because there's no accumulator to drift.
- **Backgrounding becomes trivial.** The OS suspends you for 4 minutes? On resume, call `resolve(state, DateTime.now())` and you're exactly right. No catch-up logic, no reconciliation.
- **Testable.** Inject `now` and you can test a full 12-round workout in microseconds without any real time passing.
- **Cheap.** The ticker's only job is to trigger a repaint, not to compute state.

### Precompute the schedule

At workout start, build an immutable `List<PhaseSpan>` — every phase's start/end offset from zero, plus every cue's exact fire offset:

```dart
class PhaseSpan {
  final WorkoutPhase phase;
  final int roundNumber;
  final Duration start;   // offset from workout t=0
  final Duration end;
}

class CueEvent {
  final CueType type;     // preFinish, finish, preStart, start, beep, workoutEnd
  final Duration at;      // offset from workout t=0
}
```

This schedule is the **single source of truth** for both the UI and the audio system. It gets recomputed only on pause/resume/skip/config-change.

### Acceptance criteria — Phase 1

- `resolve()` is pure, has no dependency on `DateTime.now()` internally (time is injected), and allocates nothing on the hot path.
- Unit test: simulate a full 12×3/1 workout by advancing an injected clock; assert every phase boundary and every cue offset lands on the exact expected millisecond.
- Unit test: pause for an arbitrary duration mid-round, resume, assert the remaining time is unchanged and all subsequent cue offsets shift by exactly the pause duration.
- Unit test: skip a phase, assert the schedule recomputes correctly and no cue from the skipped phase can still fire.
- Kill the app mid-workout, relaunch, and (if you persist `startedAt`) the timer resumes at the correct point. *(Decide with me whether to persist across cold launch — see Open Questions.)*

---

## Phase 2 — Background execution

Two platforms, two mechanisms, one shared abstraction. Build a `BackgroundSessionService` interface with an Android and an iOS implementation behind it.

### The key insight

You are **not** trying to keep Dart code running in the background. You are trying to make sure **audio fires at the right moments** while backgrounded. Those are different problems, and the second one is much easier.

Since Phase 1 gives you a fully precomputed cue schedule the moment the workout starts, you know every cue's exact timestamp up front. So: **hand the whole schedule to the platform's audio layer and let the OS play it**, rather than trying to stay awake and trigger each cue yourself.

### iOS

**Primary mechanism: background audio session.**

1. Add `UIBackgroundModes: [audio]` to `Info.plist`.
2. Set the `AVAudioSession` category to **`playback`** with the `.mixWithOthers` option. This is what makes cues audible over the silent switch *and* lets the app keep running while backgrounded — the same capability Spotify uses.
3. **Keep the audio session alive for the full workout** by playing a near-silent looping track underneath. Without active playback, iOS will suspend you within seconds. Generate a 1-second silent (or -60dB) loop, `silence.wav`, and loop it for the workout's duration.
4. Cues play over the silence loop through the same session.
5. `.mixWithOthers` means the user's music keeps playing — critical, since people box to music. Consider `.duckOthers` instead so the bell cuts through; make it a setting.

> **Review risk, flagged honestly:** the silent-keep-alive-track pattern is widely used by interval timer apps and Apple generally accepts it for this category of app, but it is not explicitly blessed and reviewers have rejected apps that use background audio without genuinely being audio apps. Cornerman *is* genuinely an audio app (the cues are the product), so the justification is strong. Mitigate by: (a) only running the session while a workout is active, never at idle; (b) showing a Now Playing / lock-screen control so the background audio is visible and user-initiated; (c) writing a clear note in App Review Notes explaining the timer's cues require background audio.

**Belt-and-braces fallback: pre-scheduled local notifications.**

Also schedule a `UNNotificationRequest` with a custom sound for each cue at its exact timestamp (via `flutter_local_notifications`). If iOS suspends the audio session anyway (low-power mode, an edge case, an OS update), the notifications still fire. Cancel and reschedule the whole set on pause/resume/skip/reset.

Constraints to respect: notification sounds must be ≤30s, bundled in the app, and in CAF/AIFF/WAV — **not MP3**. Cue assets are now shipped as WAV, which satisfies this constraint directly — no second-format conversion needed; the same files serve in-session playback and the notification fallback. Note that notification sounds route through the ringer channel and *are* silenced by the mute switch, which is precisely why the audio session is the primary path and this is only the fallback.

### Android

**Mechanism: foreground service.**

1. Use `flutter_foreground_task` (or a hand-rolled foreground service) to run the workout in a foreground service with a persistent notification. This is the sanctioned way to keep a process alive indefinitely, and it's exactly what native stopwatch apps do.
2. Declare `android:foregroundServiceType="mediaPlayback"` and the `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission. Targeting Android 14+, a foreground service type is mandatory and `mediaPlayback` is the honest fit.
3. Request `POST_NOTIFICATIONS` at runtime (Android 13+).
4. The notification should be **useful, not just legally required**: show the current phase, round number, and a live countdown, plus Pause/Resume and Stop actions. This is the Spotify-like experience you asked for.
5. Set the audio attributes to `USAGE_MEDIA` / `CONTENT_TYPE_SONIFICATION` and request transient audio focus with ducking, so the bell cuts through the user's music without stopping it.
6. **Battery optimization:** on aggressive OEM skins (Xiaomi, Huawei, Samsung), foreground services still get killed. Detect this and, on first workout, offer a one-tap prompt to disable battery optimization for the app. Don't nag — ask once, remember the answer.

### Shared: media session / lock-screen controls

Wire up `audio_service` (or platform media session APIs directly) so both platforms get:

- Lock-screen and notification-shade controls (Pause / Resume / Stop / Skip)
- Correct behavior when headphones disconnect (pause? keep going? — make it a setting; default: keep going, since a boxer yanking earbuds mid-round doesn't want the round to stop)

This is the thing that will make it *feel* native rather than like a web app in a wrapper.

### Acceptance criteria — Phase 2

- Start a 12-round workout, background the app, lock the phone, put it in a pocket. **Every cue fires audibly, at the right second, for the entire ~48 minutes.** Test on both platforms.
- Test with Spotify playing simultaneously: music keeps playing, cues are clearly audible over it.
- Test with the iPhone mute switch **on**: cues still audible.
- Lock screen shows current round + phase + countdown, with working Pause/Stop controls.
- Kill the app from the app switcher: the foreground service/session stops cleanly, no orphaned notification, no zombie audio.
- Airplane mode / no network: everything works (nothing here should touch the network).
- Android: verify on an OEM device with aggressive battery management (or emulate by enabling "Restricted" battery mode) and document the behavior.

---

## Phase 3 — Performance & footprint

Do this **after** Phase 1, because Phase 1 removes most of the performance problem for free (a derived-state timer doesn't rebuild the world every tick).

### Rendering — the hot path

The screen updates 60×/sec. Almost nothing on it actually *changes* 60×/sec. Enforce that:

1. **Nothing above the countdown may rebuild on a tick.** Drive the ticker into a single `AnimationController`/`Ticker`, and consume it with `AnimatedBuilder`/`ValueListenableBuilder` scoped *only* to the widgets whose pixels change. The scaffold, the round label, the buttons, the background — all `const`, all built once.
2. **Split the two update rates.** The MM:SS digits change once per second. The progress ring changes every frame. These are different `ValueNotifier`s at different granularities — do not repaint the digits 60×/sec to update a ring.
3. **Progress ring = one `CustomPainter`, wrapped in `RepaintBoundary`.** `shouldRepaint` compares a single double. No widget rebuild at all — just a repaint of one layer.
4. **Never `setState` on the tick.** If Claude Code finds `setState` in a ticker callback in the existing code, that's the primary perf bug; fix it first.
5. **Ban the expensive primitives:** no `Opacity` (use `AnimatedOpacity` sparingly, or bake alpha into the paint), no `BackdropFilter`, no drop shadows on animated elements, no `ClipRRect` on the animating layer. These force offscreen compositing passes that murder low-end GPUs.
6. **Precompute layout-invariant values.** The auto-scaling font size should be computed once per layout change (`LayoutBuilder`), not per frame.

### Audio

7. **Preload every cue into a pooled player at startup.** Never construct an `AudioPlayer` in response to a cue — the allocation + decode latency will make the bell land late, which is a *correctness* bug for a timer, not just a perf one.
8. **Prime the audio pipeline on Start** by playing a zero-volume sample, so the very first cue isn't delayed by cold-start latency.
9. **Keep assets lean:** mono, 16-bit PCM, trimmed to remove leading silence (leading silence = a late-sounding bell). Cue assets are WAV (uncompressed, required for the iOS notification-sound fallback in Phase 2), so they're larger than MP3 per cue — watch the running total against the app-size budget below and trim duration/sample rate if needed rather than reaching for lossy compression, which would break the notification-sound constraint.

### App size & startup

10. **Build with `--split-per-abi`** (Android) and let tree-shaking of icons run. Target a **<15MB** download.
11. **Nothing heavy in `main()`.** Load config from `shared_preferences` and preload audio *asynchronously* behind a fast first frame. Target **<1s cold start to interactive** on a low-end device.
12. **Audit the dependency list.** Every package is startup cost and size. If a package is used for one function, inline the function and drop the package. Report the final list with justification for each.
13. **No dev-only deps in the release build.** Verify.

### Acceptance criteria — Phase 3

Measure, don't assert. Claude Code must produce actual numbers:

- **`flutter run --profile` + DevTools timeline:** during an active round, **zero janked frames** over a 60-second capture. Both raster and UI threads under budget (<16ms; ideally the UI thread is near-idle).
- **Widget rebuild count per tick:** instrument and report. Target: **the digit widget and the ring painter, and nothing else.**
- **Memory:** steady-state heap during a workout should be flat — no growth over 12 rounds. Report before/after.
- **APK size:** report `--analyze-size` output. Target <15MB per-ABI.
- **Cold start:** measure with `flutter run --profile --trace-startup`. Report `timeToFirstFrameMicros`.
- **Low-end validation:** test on a genuinely weak device or an emulator throttled to low specs. The countdown must be visibly smooth.
- **Battery:** run a full 48-minute workout backgrounded and report battery drain %. This is the number that matters most for a gym app.

---

## Phase 4 — Robustness (the things that break in a real gym)

- **Incoming phone call mid-round:** audio session interrupted. On interruption end, the timer must be *correct* (it will be, thanks to Phase 1) and audio must resume. Handle `AVAudioSession` interruption notifications / Android `AUDIOFOCUS_LOSS_TRANSIENT`.
- **Bluetooth speaker/earbud latency:** BT adds 100–200ms. Consider firing cues fractionally early when a BT route is active, or at minimum don't be surprised by it. Document the behavior.
- **Device sleeps / screen off:** covered by Phase 2, but test explicitly with the wakelock *released* (user might turn the screen off manually).
- **Clock changes / DST / user changes system time mid-workout:** use a monotonic clock source (`Stopwatch` elapsed against a captured anchor) rather than raw `DateTime.now()` for the elapsed calculation, so a system clock change can't teleport the workout. *This is a real edge case for a wall-clock-derived design — handle it deliberately.*
- **Rotation mid-round:** state survives, no cue re-fires.

---

## Open questions for me (ask before implementing)

1. **Cold-launch resume:** if the user force-quits mid-workout and reopens, should the workout resume where it would be now (wall-clock continued), or reset? I lean *reset* — a boxer who force-quits has stopped boxing — but ask me.
2. **Music behavior:** duck the user's music on each bell, or mix without ducking? Ducking is clearer but more intrusive. Default + setting?
3. **Headphone disconnect:** keep going (my default) or auto-pause?

---

## Order of work — summary

| Phase | What | Blocks |
|---|---|---|
| 0 | Audit + gap analysis | everything |
| 1 | Wall-clock-derived timer engine | 2 and 3 |
| 2 | Background execution (iOS session + Android FGS) | — |
| 3 | Performance + footprint | — |
| 4 | Interruption/edge-case robustness | — |

**Do not begin Phase 2 until Phase 1's unit tests pass.** Background execution built on a drifting timer is unfixable; built on a derived timer it's almost free.
