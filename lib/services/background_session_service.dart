import 'dart:async';

import 'package:audio_service/audio_service.dart' as svc;
import 'package:audio_session/audio_session.dart' as session;
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout_phase.dart';
import '../models/workout_snapshot.dart';

final backgroundSessionServiceProvider =
    Provider<BackgroundSessionService>((ref) {
  final s = BackgroundSessionService();
  ref.onDispose(s.dispose);
  return s;
});

/// The subset of [BackgroundSessionService] that `TimerNotifier` depends on,
/// kept narrow rather than depending on the full `audio_service`
/// `AudioHandler` surface (~30 unrelated members) — this is what lets tests
/// fake it with a handful of no-op methods instead of implementing the
/// entire third-party interface.
abstract class BackgroundSession {
  Future<void> startSession();
  Future<void> endSession();
  void syncFromSnapshot(WorkoutSnapshot snapshot);
}

/// Keeps a workout alive in the background. A near-silent looping track
/// holds the iOS audio session open (without it, iOS suspends the app
/// within seconds of backgrounding); pairing that with `audio_service`'s
/// media session also gets Cornerman an Android foreground service and
/// lock-screen/notification transport controls for free.
///
/// Cue sounds themselves are unaffected — they keep playing through the
/// existing pooled `AudioService` exactly as before. This class only holds
/// the session open and exposes/reflects transport state.
class BackgroundSessionService extends svc.BaseAudioHandler
    implements BackgroundSession {
  final ap.AudioPlayer _loopPlayer = ap.AudioPlayer()
    ..setReleaseMode(ap.ReleaseMode.loop);

  StreamSubscription<session.AudioInterruptionEvent>? _interruptionSub;

  void Function()? _onPlay;
  void Function()? _onPause;
  void Function()? _onStop;
  void Function()? _onSkip;

  /// Wires transport controls (lock screen / notification) to the timer
  /// engine. Called once, immediately after `TimerNotifier` is constructed —
  /// this service is a constructor dependency of the notifier, so the
  /// notifier can't be passed in here directly without a cycle.
  void bind({
    required void Function() onPlay,
    required void Function() onPause,
    required void Function() onStop,
    required void Function() onSkip,
  }) {
    _onPlay = onPlay;
    _onPause = onPause;
    _onStop = onStop;
    _onSkip = onSkip;
  }

  bool get _active =>
      playbackState.value.processingState != svc.AudioProcessingState.idle;

  /// Begins the session: strictly scoped to "workout active" (never idle),
  /// per the App Review guidance in the plan — a persistent background
  /// audio session/notification should only exist while a workout is
  /// actually running.
  @override
  Future<void> startSession() async {
    if (_active) return;
    await _startInterruptionListener();
    final s = await session.AudioSession.instance;
    await s.setActive(true);
    await _loopPlayer.play(ap.AssetSource('sounds/silence.wav'), volume: 0.001);
    playbackState.add(playbackState.value.copyWith(
      processingState: svc.AudioProcessingState.ready,
      playing: true,
      controls: const [
        svc.MediaControl.stop,
        svc.MediaControl.pause,
        svc.MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 1, 2],
    ));
  }

  /// Idempotent teardown: stops the keep-alive loop and clears the
  /// notification/session. Safe to call even if no session is active.
  @override
  Future<void> endSession() async {
    if (!_active) return;
    await _loopPlayer.stop();
    final s = await session.AudioSession.instance;
    await s.setActive(false);
    playbackState.add(playbackState.value.copyWith(
      processingState: svc.AudioProcessingState.idle,
      playing: false,
    ));
    mediaItem.add(null);
  }

  /// Registers for OS audio interruption events (incoming phone call,
  /// another app taking audio focus / Android `AUDIOFOCUS_LOSS_TRANSIENT`)
  /// exactly once. Phase 1's wall-clock design means the timer itself never
  /// needs correcting when an interruption ends — `resolve()` is already
  /// exactly right — but iOS deactivates the shared audio session for the
  /// duration of the interruption, which stops the silent keep-alive loop
  /// dead. Without an explicit nudge back on here, every cue for the rest
  /// of the workout would go silent even though the countdown is correct.
  Future<void> _startInterruptionListener() async {
    if (_interruptionSub != null) return;
    final s = await session.AudioSession.instance;
    await s.configure(const session.AudioSessionConfiguration(
      avAudioSessionCategory: session.AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          session.AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: session.AVAudioSessionMode.defaultMode,
      androidAudioAttributes: session.AndroidAudioAttributes(
        contentType: session.AndroidAudioContentType.sonification,
        usage: session.AndroidAudioUsage.alarm,
      ),
      androidAudioFocusGainType: session.AndroidAudioFocusGainType.gain,
    ));
    _interruptionSub = s.interruptionEventStream.listen((event) {
      if (!event.begin) _reactivateAfterInterruption();
    });
  }

  Future<void> _reactivateAfterInterruption() async {
    if (!_active) return;
    await _loopPlayer.resume();
  }

  /// Pushes the current workout snapshot to the lock screen / notification:
  /// phase + round as the title/artist, and phase progress as the position.
  @override
  void syncFromSnapshot(WorkoutSnapshot snap) {
    if (!_active) return;
    playbackState.add(playbackState.value.copyWith(
      playing: snap.isRunning,
      controls: [
        svc.MediaControl.stop,
        snap.isRunning ? svc.MediaControl.pause : svc.MediaControl.play,
        svc.MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      updatePosition:
          Duration(milliseconds: snap.totalPhaseMs - snap.remainingMs),
    ));
    mediaItem.add(svc.MediaItem(
      id: 'cornerman-workout',
      title: _phaseLabel(snap.phase),
      artist: snap.currentRound > 0
          ? 'Round ${snap.currentRound}/${snap.config.rounds}'
          : null,
      duration: Duration(milliseconds: snap.totalPhaseMs),
    ));
  }

  String _phaseLabel(WorkoutPhase phase) => switch (phase) {
        WorkoutPhase.idle => 'Ready',
        WorkoutPhase.prep => 'Get Ready',
        WorkoutPhase.round => 'Fight',
        WorkoutPhase.rest => 'Rest',
        WorkoutPhase.finished => 'Done',
      };

  // ── transport controls, delegated to TimerNotifier via bind() ──────────

  @override
  Future<void> play() async => _onPlay?.call();

  @override
  Future<void> pause() async => _onPause?.call();

  // TimerNotifier.reset() is the source of truth for tearing the session
  // down (via endSession()); this just forwards the click.
  @override
  Future<void> stop() async => _onStop?.call();

  @override
  Future<void> skipToNext() async => _onSkip?.call();

  void dispose() {
    _interruptionSub?.cancel();
    _loopPlayer.dispose();
  }
}
