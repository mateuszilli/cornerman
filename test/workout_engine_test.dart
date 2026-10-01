import 'package:flutter_test/flutter_test.dart';
import 'package:cornerman/models/timer_config.dart';
import 'package:cornerman/models/workout_phase.dart';
import 'package:cornerman/models/workout_schedule.dart';
import 'package:cornerman/models/workout_snapshot.dart';
import 'package:cornerman/models/workout_state.dart';
import 'package:cornerman/services/audio_service.dart';
import 'package:cornerman/services/background_session_service.dart';
import 'package:cornerman/services/haptic_service.dart';
import 'package:cornerman/services/notification_fallback_service.dart';
import 'package:cornerman/services/prefs_service.dart';
import 'package:cornerman/state/timer_notifier.dart';

// Same fakes as timer_notifier_test.dart, duplicated locally so this file
// has no dependency on real audio/haptic/prefs plugins or real time.
class FakeAudioService implements AudioService {
  final List<AudioCue> played = [];

  @override
  void play(AudioCue cue) => played.add(cue);

  @override
  void stop() {}

  @override
  void setVolume(double v) {}

  @override
  void setMuted(bool m) {}

  @override
  void setDuckAudio(bool duckAudio) {}

  @override
  bool get muted => false;

  @override
  double get volume => 1.0;

  @override
  Future<void> preload() async {}

  @override
  void dispose() {}
}

class FakeHapticService implements HapticService {
  @override
  Future<void> buzz() async {}

  @override
  Future<void> longBuzz() async {}
}

class FakePrefsService implements PrefsService {
  @override
  Future<TimerConfig?> loadLastConfig() async => null;

  @override
  Future<void> saveConfig(TimerConfig c) async {}

  @override
  Future<List<NamedPreset>> loadUserPresets() async => [];

  @override
  Future<void> saveUserPresets(List<NamedPreset> presets) async {}

  @override
  Future<String?> loadLocale() async => null;

  @override
  Future<void> saveLocale(String? code) async {}
}

class FakeBackgroundSession implements BackgroundSession {
  @override
  Future<void> startSession() async {}

  @override
  Future<void> endSession() async {}

  @override
  void syncFromSnapshot(WorkoutSnapshot snapshot) {}
}

class FakeNotificationFallback implements NotificationFallback {
  @override
  Future<void> scheduleAll(WorkoutState state, WorkoutSchedule schedule) async {}

  @override
  Future<void> cancelAll() async {}
}

void main() {
  group('WorkoutSchedule — championship (12x3/1)', () {
    // rounds:12 roundSeconds:180 restSeconds:60 prepSeconds:10 warningSeconds:10
    const cfg = TimerConfig.championship;
    final schedule = WorkoutSchedule.build(cfg);

    test('total duration is exactly prep + 12 rounds + 11 rests', () {
      // 10 + 12*180 + 11*60 = 10 + 2160 + 660 = 2830s
      expect(schedule.totalDuration, const Duration(seconds: 2830));
    });

    test('every round/rest boundary lands on the exact expected millisecond', () {
      for (var round = 1; round <= 12; round++) {
        final expectedStart = Duration(seconds: 10 + (round - 1) * 240);
        final expectedEnd = expectedStart + const Duration(seconds: 180);
        final span = schedule.spans.firstWhere(
          (s) => s.phase == WorkoutPhase.round && s.roundNumber == round,
        );
        expect(span.start, expectedStart, reason: 'round $round start');
        expect(span.end, expectedEnd, reason: 'round $round end');

        if (round < 12) {
          final restSpan = schedule.spans.firstWhere(
            (s) => s.phase == WorkoutPhase.rest && s.roundNumber == round,
          );
          expect(restSpan.start, expectedEnd, reason: 'rest $round start');
          expect(
            restSpan.end,
            expectedEnd + const Duration(seconds: 60),
            reason: 'rest $round end',
          );
        }
      }
    });

    test('cue offsets land on the exact expected millisecond', () {
      bool hasCue(CueType type, Duration at) =>
          schedule.cues.any((c) => c.type == type && c.at == at);

      // Round 1: start at prep end (10s), preFinish at 190-10=180s, finish at 190s.
      expect(hasCue(CueType.start, const Duration(seconds: 10)), isTrue);
      expect(hasCue(CueType.preFinish, const Duration(seconds: 180)), isTrue);
      expect(hasCue(CueType.finish, const Duration(seconds: 190)), isTrue);

      // Round 7 starts at 10 + 6*240 = 1450s.
      expect(hasCue(CueType.start, const Duration(seconds: 1450)), isTrue);

      // Round 12 (last) ends exactly at total duration; workoutEnd fires there too.
      expect(hasCue(CueType.finish, const Duration(seconds: 2830)), isTrue);
      expect(hasCue(CueType.workoutEnd, const Duration(seconds: 2830)), isTrue);

      // Prep countdown: warningSeconds==prepSeconds==10, so preStart at t=0,
      // beeps at t=7,8,9.
      expect(hasCue(CueType.preStart, Duration.zero), isTrue);
      expect(hasCue(CueType.beep, const Duration(seconds: 7)), isTrue);
      expect(hasCue(CueType.beep, const Duration(seconds: 8)), isTrue);
      expect(hasCue(CueType.beep, const Duration(seconds: 9)), isTrue);
    });

    test('cues are sorted ascending, finish-before-start on shared instants', () {
      for (var i = 1; i < schedule.cues.length; i++) {
        expect(
          schedule.cues[i].at >= schedule.cues[i - 1].at,
          isTrue,
          reason: 'cue $i out of order',
        );
      }
      final atTotal =
          schedule.cues.where((c) => c.at == schedule.totalDuration).toList();
      expect(atTotal.map((c) => c.type).toList(),
          [CueType.finish, CueType.workoutEnd]);
    });
  });

  group('resolve() — pure function of injected time, no real delay', () {
    const cfg = TimerConfig.championship;
    final schedule = WorkoutSchedule.build(cfg);
    final epoch = DateTime(2026, 1, 1);

    WorkoutSnapshot at(Duration elapsed) {
      final state = WorkoutState(config: cfg, startedAt: epoch);
      return resolve(state, schedule, epoch.add(elapsed));
    }

    test('idle before start', () {
      final snap = resolve(WorkoutState.idle(cfg), schedule, epoch);
      expect(snap.phase, WorkoutPhase.idle);
    });

    test('prep at t=0 and just before it ends', () {
      expect(at(Duration.zero).phase, WorkoutPhase.prep);
      expect(at(const Duration(milliseconds: 9999)).phase, WorkoutPhase.prep);
      expect(at(const Duration(milliseconds: 9999)).remainingMs, 1);
    });

    test('round 1 begins exactly at prep end, full duration remaining', () {
      final snap = at(const Duration(seconds: 10));
      expect(snap.phase, WorkoutPhase.round);
      expect(snap.currentRound, 1);
      expect(snap.remainingMs, 180000);
    });

    test('rest 1 begins exactly at round 1 end', () {
      final snap = at(const Duration(seconds: 190));
      expect(snap.phase, WorkoutPhase.rest);
      expect(snap.currentRound, 1);
      expect(snap.remainingMs, 60000);
    });

    test('round 2 begins exactly at rest 1 end', () {
      final snap = at(const Duration(seconds: 250));
      expect(snap.phase, WorkoutPhase.round);
      expect(snap.currentRound, 2);
    });

    test('finished exactly at total duration, and stays finished after', () {
      final onBoundary = at(const Duration(seconds: 2830));
      expect(onBoundary.phase, WorkoutPhase.finished);
      expect(onBoundary.currentRound, 12);

      final wellAfter = at(const Duration(seconds: 9999));
      expect(wellAfter.phase, WorkoutPhase.finished);
    });

    test('microsecond-precision full-workout walk hits every boundary exactly',
        () {
      // Simulate the entire 12x3/1 workout by advancing an injected clock —
      // no real time passes — and assert every span transition is exact.
      for (final span in schedule.spans) {
        final justBefore = span.end - const Duration(milliseconds: 1);
        if (justBefore >= span.start) {
          expect(at(justBefore).phase, span.phase,
              reason: '1ms before ${span.phase} r${span.roundNumber} ends');
        }
        if (span.end < schedule.totalDuration) {
          final nextSnap = at(span.end);
          expect(nextSnap.phase, isNot(equals(span.phase)),
              reason: 'phase must change exactly at ${span.end}');
        }
      }
    });
  });

  group('Pause/resume — remaining time and subsequent offsets shift exactly',
      () {
    test('pausing for an arbitrary duration does not change remaining time,'
        ' and resuming shifts all subsequent boundaries by exactly that pause',
        () {
      const cfg = TimerConfig.championship;
      final schedule = WorkoutSchedule.build(cfg);
      final epoch = DateTime(2026, 1, 1);

      // Start, run into round 1 (t = 10s + 30s = 40s elapsed), then pause.
      var state = WorkoutState(config: cfg, startedAt: epoch);
      final pauseAt = epoch.add(const Duration(seconds: 40));
      final beforePause = resolve(state, schedule, pauseAt);
      expect(beforePause.phase, WorkoutPhase.round);
      final remainingAtPause = beforePause.remainingMs;

      state = state.copyWith(pausedAt: pauseAt);

      // Arbitrary pause duration — pick something odd, e.g. 137.25 minutes
      // worth of milliseconds, to prove there's no drift regardless of length.
      const pauseDuration = Duration(minutes: 137, seconds: 15);

      // While paused, remaining must not change no matter how far `now` moves.
      final duringPause1 = resolve(state, schedule, pauseAt.add(const Duration(seconds: 5)));
      final duringPause2 =
          resolve(state, schedule, pauseAt.add(pauseDuration - const Duration(seconds: 1)));
      expect(duringPause1.remainingMs, remainingAtPause);
      expect(duringPause2.remainingMs, remainingAtPause);
      expect(duringPause1.phase, WorkoutPhase.round);

      // Resume: pausedOffset accumulates the pause, pausedAt clears.
      final resumeWallClock = pauseAt.add(pauseDuration);
      state = state.copyWith(
        pausedOffset: state.pausedOffset + pauseDuration,
        clearPausedAt: true,
      );

      // Remaining is unchanged at the instant of resume.
      final atResume = resolve(state, schedule, resumeWallClock);
      expect(atResume.remainingMs, remainingAtPause);
      expect(atResume.phase, WorkoutPhase.round);

      // Every subsequent boundary is shifted forward by exactly the pause
      // duration relative to wall-clock: round 1 originally ended at
      // epoch+190s, so post-pause it ends at epoch+190s+pauseDuration.
      final originalRound1End = epoch.add(const Duration(seconds: 190));
      final shiftedRound1End = originalRound1End.add(pauseDuration);

      final justBeforeShiftedEnd =
          resolve(state, schedule, shiftedRound1End.subtract(const Duration(milliseconds: 1)));
      expect(justBeforeShiftedEnd.phase, WorkoutPhase.round);

      final atShiftedEnd = resolve(state, schedule, shiftedRound1End);
      expect(atShiftedEnd.phase, WorkoutPhase.rest);
    });
  });

  group('skipPhase — cancels every cue in the skipped remainder', () {
    test('skipping mid-round fires only the boundary cue, never the '
        'pre-finish warning or beeps that would have played in between', () {
      const cfg = TimerConfig(
        rounds: 3,
        roundSeconds: 20,
        restSeconds: 10,
        prepSeconds: 0,
        warningSeconds: 5,
        countdownBeeps: true,
        haptics: false,
        keepScreenAwake: false,
        volume: 1.0,
        muted: false,
        duckAudio: true,
      );
      final audio = FakeAudioService();
      final n = TimerNotifier(
        audioService: audio,
        hapticService: FakeHapticService(),
        prefsService: FakePrefsService(),
        backgroundSession: FakeBackgroundSession(),
        notificationFallback: FakeNotificationFallback(),
      );
      n.loadConfig(cfg);
      n.start(); // round 1 begins, fires AudioCue.start
      expect(audio.played, [AudioCue.start]);

      audio.played.clear();
      n.skipPhase(); // round 1 -> rest 1, well before the preFinish warning

      // Only the round-end "finish" cue should have fired — never preFinish.
      expect(audio.played, [AudioCue.finish]);
      expect(n.state.phase, WorkoutPhase.rest);
      n.dispose();
    });

    test('skipping through rest cancels its lead-in beeps but the next '
        'round still starts cleanly with its own start cue', () {
      const cfg = TimerConfig(
        rounds: 3,
        roundSeconds: 20,
        restSeconds: 10,
        prepSeconds: 0,
        warningSeconds: 5,
        countdownBeeps: true,
        haptics: false,
        keepScreenAwake: false,
        volume: 1.0,
        muted: false,
        duckAudio: true,
      );
      final audio = FakeAudioService();
      final n = TimerNotifier(
        audioService: audio,
        hapticService: FakeHapticService(),
        prefsService: FakePrefsService(),
        backgroundSession: FakeBackgroundSession(),
        notificationFallback: FakeNotificationFallback(),
      );
      n.loadConfig(cfg);
      n.start(); // round 1
      n.skipPhase(); // -> rest 1
      audio.played.clear();

      n.skipPhase(); // -> round 2, skipping rest's preStart/beep cues

      expect(audio.played, [AudioCue.start]);
      expect(n.state.phase, WorkoutPhase.round);
      expect(n.state.currentRound, 2);
      n.dispose();
    });

    test('skipping the final round jumps straight to finished, firing '
        'finish and workoutEnd but no dangling round cues', () {
      const cfg = TimerConfig(
        rounds: 1,
        roundSeconds: 20,
        restSeconds: 10,
        prepSeconds: 0,
        warningSeconds: 5,
        countdownBeeps: true,
        haptics: false,
        keepScreenAwake: false,
        volume: 1.0,
        muted: false,
        duckAudio: true,
      );
      final audio = FakeAudioService();
      final n = TimerNotifier(
        audioService: audio,
        hapticService: FakeHapticService(),
        prefsService: FakePrefsService(),
        backgroundSession: FakeBackgroundSession(),
        notificationFallback: FakeNotificationFallback(),
      );
      n.loadConfig(cfg);
      n.start();
      audio.played.clear();

      n.skipPhase();

      expect(audio.played, [AudioCue.finish, AudioCue.end]);
      expect(n.state.phase, WorkoutPhase.finished);
      n.dispose();
    });
  });

  group('NotificationFallbackService.fallbackCues — iOS 64-notification cap', () {
    test('championship (12x3/1) fallback cue count stays comfortably under 64', () {
      final schedule = WorkoutSchedule.build(TimerConfig.championship);
      final fallback = NotificationFallbackService.fallbackCues(schedule);
      expect(fallback.length, 49);
      expect(fallback.length, lessThan(64));
    });

    test('excludes countdown beeps, includes only boundary cue types', () {
      final schedule = WorkoutSchedule.build(TimerConfig.championship);
      final fallback = NotificationFallbackService.fallbackCues(schedule);
      expect(fallback.any((c) => c.type == CueType.beep), isFalse);
      expect(
        fallback.map((c) => c.type).toSet(),
        {
          CueType.preStart,
          CueType.start,
          CueType.preFinish,
          CueType.finish,
          CueType.workoutEnd,
        },
      );
    });
  });
}
