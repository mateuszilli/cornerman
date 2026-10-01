import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/timer_config.dart';
import '../models/workout_phase.dart';
import '../models/workout_schedule.dart';
import '../models/workout_snapshot.dart';
import '../models/workout_state.dart';
import '../services/audio_service.dart';
import '../services/background_session_service.dart';
import '../services/clock_service.dart';
import '../services/haptic_service.dart';
import '../services/notification_fallback_service.dart';
import '../services/prefs_service.dart';

final timerProvider = ChangeNotifierProvider<TimerNotifier>((ref) {
  final backgroundSession = ref.watch(backgroundSessionServiceProvider);
  final notifier = TimerNotifier(
    audioService: ref.watch(audioServiceProvider),
    hapticService: ref.watch(hapticServiceProvider),
    prefsService: ref.watch(prefsServiceProvider),
    backgroundSession: backgroundSession,
    notificationFallback: ref.watch(notificationFallbackServiceProvider),
    clock: ref.watch(clockServiceProvider),
  );
  // BackgroundSessionService (a constructor dependency of this notifier)
  // can't take the notifier itself to avoid a construction cycle, so
  // transport controls (lock screen / notification) are wired here instead.
  backgroundSession.bind(
    onPlay: notifier.start,
    onPause: notifier.pause,
    onStop: notifier.reset,
    onSkip: notifier.skipPhase,
  );
  return notifier;
});

/// Engine for a workout timer whose only mutable state is [WorkoutState].
/// The ticker's sole job is to trigger cue playback and a repaint signal —
/// current phase, round, and remaining time are always derived fresh via
/// `resolve()`, never accumulated.
class TimerNotifier extends ChangeNotifier {
  TimerNotifier({
    required this.audioService,
    required this.hapticService,
    required this.prefsService,
    required this.backgroundSession,
    required this.notificationFallback,
    ClockService? clock,
  })  : clock = clock ?? ClockService(),
        _workoutState = WorkoutState.idle(TimerConfig.championship),
        _schedule = WorkoutSchedule.build(TimerConfig.championship);

  final AudioService audioService;
  final HapticService hapticService;
  final PrefsService prefsService;
  final BackgroundSession backgroundSession;
  final NotificationFallback notificationFallback;
  final ClockService clock;

  WorkoutState _workoutState;
  WorkoutSchedule _schedule;
  Timer? _ticker;
  int _cueCursor = 0;

  // Hot-path values, updated every tick. Widgets that only need these
  // (the digits, the progress ring) listen here directly instead of via
  // `ref.watch(timerProvider)`, so a tick never rebuilds the rest of the
  // screen — only `notifyListeners()` (fired solely on coarse transitions
  // in `_publish`) does that.
  final ValueNotifier<int> remainingSecondsNotifier = ValueNotifier(0);
  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);

  WorkoutPhase _lastPhase = WorkoutPhase.idle;
  int _lastRound = 0;
  bool _lastRunning = false;

  WorkoutSnapshot get state => resolve(_workoutState, _schedule, clock.now());

  /// Updates the hot-path notifiers unconditionally, but only calls
  /// `notifyListeners()` — and therefore only rebuilds the coarse UI — when
  /// phase, round, or running state actually changed.
  void _publish(WorkoutSnapshot snap, {bool forceNotify = false}) {
    remainingSecondsNotifier.value = snap.remainingSeconds;
    progressNotifier.value = snap.progress;
    final coarseChanged = snap.phase != _lastPhase ||
        snap.currentRound != _lastRound ||
        snap.isRunning != _lastRunning;
    if (coarseChanged || forceNotify) {
      _lastPhase = snap.phase;
      _lastRound = snap.currentRound;
      _lastRunning = snap.isRunning;
      notifyListeners();
    }
  }

  void loadConfig(TimerConfig config) {
    if (state.isRunning) return;
    _workoutState = WorkoutState.idle(config);
    _schedule = WorkoutSchedule.build(config);
    _cueCursor = 0;
    audioService.setDuckAudio(config.duckAudio);
    _publish(state, forceNotify: true);
  }

  void start() {
    final snap = state;
    if (snap.phase == WorkoutPhase.idle || snap.phase == WorkoutPhase.finished) {
      _schedule = WorkoutSchedule.build(_workoutState.config);
      _workoutState = WorkoutState(
        config: _workoutState.config,
        startedAt: clock.now(),
      );
      _cueCursor = 0;
      _processCuesUpTo(Duration.zero);
      _syncTicker();
      backgroundSession.startSession();
      notificationFallback.scheduleAll(_workoutState, _schedule);
      _syncBackground();
      _publish(state, forceNotify: true);
    } else if (!snap.isRunning) {
      resume();
    }
  }

  void pause() {
    if (!state.isRunning) return;
    _workoutState = _workoutState.copyWith(pausedAt: clock.now());
    _syncTicker();
    // Cues don't move while paused, but their scheduled wall-clock fire
    // times would — cancel until resume() reschedules from the new anchor.
    notificationFallback.cancelAll();
    _syncBackground();
    _publish(state, forceNotify: true);
  }

  void resume() {
    final snap = state;
    if (snap.isRunning ||
        snap.phase == WorkoutPhase.idle ||
        snap.phase == WorkoutPhase.finished ||
        !_workoutState.isPaused) {
      return;
    }
    final now = clock.now();
    final pausedDuration = now.difference(_workoutState.pausedAt!);
    _workoutState = _workoutState.copyWith(
      pausedOffset: _workoutState.pausedOffset + pausedDuration,
      clearPausedAt: true,
    );
    _syncTicker();
    notificationFallback.scheduleAll(_workoutState, _schedule);
    _syncBackground();
    _publish(state, forceNotify: true);
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    audioService.stop();
    _workoutState = WorkoutState.idle(_workoutState.config);
    _cueCursor = 0;
    backgroundSession.endSession();
    notificationFallback.cancelAll();
    _publish(state, forceNotify: true);
  }

  void skipPhase() {
    final snap = state;
    if (snap.phase == WorkoutPhase.idle || snap.phase == WorkoutPhase.finished) {
      return;
    }

    final now = clock.now();
    final elapsed = _workoutState.elapsedAt(now);
    final target = _schedule.spanAt(elapsed).end;

    // Silently advance past every cue strictly inside the skipped remainder
    // — they must never fire — then land exactly on the boundary offset so
    // whatever cue sits there (finish/start/workoutEnd) fires normally.
    final cues = _schedule.cues;
    while (_cueCursor < cues.length && cues[_cueCursor].at < target) {
      _cueCursor++;
    }

    _workoutState = _workoutState.copyWith(
      skipOffset: _workoutState.skipOffset + (target - elapsed),
    );

    _processCuesUpTo(target);
    _syncTicker();
    notificationFallback.scheduleAll(_workoutState, _schedule);
    _syncBackground();
    _publish(state, forceNotify: true);
  }

  // ── internal ──────────────────────────────────────────────────────────

  void _onTick() {
    final now = clock.now();
    final elapsed = _workoutState.elapsedAt(now);
    final clipped =
        elapsed > _schedule.totalDuration ? _schedule.totalDuration : elapsed;
    _processCuesUpTo(clipped);
    if (clipped >= _schedule.totalDuration) {
      _syncTicker();
    }
    _syncBackground();
    _publish(state);
  }

  void _syncBackground() => backgroundSession.syncFromSnapshot(state);

  void _processCuesUpTo(Duration to) {
    final cues = _schedule.cues;
    while (_cueCursor < cues.length && cues[_cueCursor].at <= to) {
      _fireCue(cues[_cueCursor]);
      _cueCursor++;
    }
  }

  void _fireCue(CueEvent cue) {
    audioService.play(_audioCueFor(cue.type));
    if (!_workoutState.config.haptics) return;
    switch (cue.type) {
      case CueType.workoutEnd:
        hapticService.longBuzz();
      case CueType.beep:
        break;
      case CueType.preFinish:
      case CueType.preStart:
      case CueType.start:
      case CueType.finish:
        hapticService.buzz();
    }
  }

  AudioCue _audioCueFor(CueType type) => switch (type) {
        CueType.preFinish => AudioCue.preFinish,
        CueType.finish => AudioCue.finish,
        CueType.preStart => AudioCue.preStart,
        CueType.start => AudioCue.start,
        CueType.beep => AudioCue.beep,
        CueType.workoutEnd => AudioCue.end,
      };

  void _syncTicker() {
    final shouldTick = state.isRunning;
    if (shouldTick && _ticker == null) {
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _onTick());
    } else if (!shouldTick && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    remainingSecondsNotifier.dispose();
    progressNotifier.dispose();
    super.dispose();
  }
}
