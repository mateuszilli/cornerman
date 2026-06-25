import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/timer_config.dart';
import '../models/workout_phase.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../services/prefs_service.dart';
import 'timer_state.dart';

final timerProvider = NotifierProvider<TimerNotifier, TimerState>(TimerNotifier.new);

class TimerNotifier extends Notifier<TimerState> {
  late final AudioService audioService;
  late final HapticService hapticService;
  late final PrefsService prefsService;

  Timer? _ticker;
  DateTime? _phaseDeadline;

  // Cue-fire guards — reset each phase so cues fire exactly once.
  bool _warnFired = false;
  bool _countdownFired3 = false;
  bool _countdownFired2 = false;
  bool _countdownFired1 = false;

  @override
  TimerState build() {
    audioService = ref.watch(audioServiceProvider);
    hapticService = ref.watch(hapticServiceProvider);
    prefsService = ref.watch(prefsServiceProvider);
    ref.onDispose(() => _ticker?.cancel());
    return TimerState.idle(TimerConfig.championship);
  }

  void loadConfig(TimerConfig config) {
    if (state.isRunning) return;
    state = TimerState.idle(config);
  }

  void start() {
    if (state.isRunning) return;
    if (state.phase == WorkoutPhase.idle ||
        state.phase == WorkoutPhase.finished) {
      _beginPhase(_firstPhase());
    } else {
      _resume();
    }

  }

  void pause() {
    if (!state.isRunning) return;
    _ticker?.cancel();
    state = state.copyWith(isRunning: false);
    // Store remaining time; deadline is invalidated when paused.
    _phaseDeadline = null;
  }

  void resume() => _resume();

  void reset() {
    _ticker?.cancel();
    _phaseDeadline = null;
    audioService.stop();
    state = TimerState.idle(state.config);
  }

  void skipPhase() {
    if (state.phase == WorkoutPhase.idle ||
        state.phase == WorkoutPhase.finished) {
      return;
    }
    _ticker?.cancel();
    _phaseDeadline = null;
    _advancePhase();
  }

  // ── internal ──────────────────────────────────────────────────────────────

  WorkoutPhase _firstPhase() =>
      state.config.prepSeconds > 0 ? WorkoutPhase.prep : WorkoutPhase.round;

  void _beginPhase(WorkoutPhase phase, {int? round}) {
    _resetCueGuards();
    final cfg = state.config;
    final r = round ?? (phase == WorkoutPhase.round ? 1 : state.currentRound);

    final int durationMs = switch (phase) {
      WorkoutPhase.prep => cfg.prepSeconds * 1000,
      WorkoutPhase.round => cfg.roundSeconds * 1000,
      WorkoutPhase.rest => cfg.restSeconds * 1000,
      _ => 0,
    };

    _phaseDeadline = DateTime.now().add(Duration(milliseconds: durationMs));

    state = state.copyWith(
      phase: phase,
      currentRound: r,
      remainingMs: durationMs,
      totalPhaseMs: durationMs,
      isRunning: true,
    );

    // Fire the transition cues for entering a new phase.
    if (phase == WorkoutPhase.round) {
      audioService.play(AudioCue.start);
      if (cfg.haptics) hapticService.buzz();
    }

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), _tick);
  }

  void _resume() {
    if (state.isRunning || state.phase == WorkoutPhase.idle) return;
    _phaseDeadline =
        DateTime.now().add(Duration(milliseconds: state.remainingMs));
    state = state.copyWith(isRunning: true);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), _tick);
  }

  void _tick(Timer _) {
    final deadline = _phaseDeadline;
    if (deadline == null) return;

    final remaining = deadline.difference(DateTime.now()).inMilliseconds;
    final clipped = remaining.clamp(0, state.totalPhaseMs);
    final secs = (clipped / 1000).ceil();

    state = state.copyWith(remainingMs: clipped);

    _checkCues(secs);

    if (remaining <= 0) {
      _ticker?.cancel();
      _advancePhase();
    }
  }

  void _checkCues(int secs) {
    final cfg = state.config;
    final phase = state.phase;

    // Pre-finish warning (round) and pre-start warning (rest/prep).
    if (!_warnFired && secs == cfg.warningSeconds) {
      _warnFired = true;
      if (phase == WorkoutPhase.round) {
        audioService.play(AudioCue.preFinish);
        if (cfg.haptics) hapticService.buzz();
      } else if (phase == WorkoutPhase.rest || phase == WorkoutPhase.prep) {
        audioService.play(AudioCue.preStart);
        if (cfg.haptics) hapticService.buzz();
      }
    }

    // Last-3 countdown beeps (prep and rest only — heard before round starts).
    if (cfg.countdownBeeps &&
        (phase == WorkoutPhase.prep || phase == WorkoutPhase.rest)) {
      if (!_countdownFired3 && secs == 3) {
        _countdownFired3 = true;
        audioService.play(AudioCue.beep);
      } else if (!_countdownFired2 && secs == 2) {
        _countdownFired2 = true;
        audioService.play(AudioCue.beep);
      } else if (!_countdownFired1 && secs == 1) {
        _countdownFired1 = true;
        audioService.play(AudioCue.beep);
      }
    }
  }

  void _advancePhase() {
    _resetCueGuards();
    final cfg = state.config;
    final phase = state.phase;
    final round = state.currentRound;

    switch (phase) {
      case WorkoutPhase.prep:
        _beginPhase(WorkoutPhase.round, round: 1);

      case WorkoutPhase.round:
        audioService.play(AudioCue.finish);
        if (cfg.haptics) hapticService.buzz();
        if (round >= cfg.rounds) {
          _enterFinished();
        } else {
          _beginPhase(WorkoutPhase.rest, round: round);
        }

      case WorkoutPhase.rest:
        _beginPhase(WorkoutPhase.round, round: round + 1);

      case WorkoutPhase.idle:
      case WorkoutPhase.finished:
        break;
    }
  }

  void _enterFinished() {
    _ticker?.cancel();
    _phaseDeadline = null;
    audioService.play(AudioCue.end);
    if (state.config.haptics) hapticService.longBuzz();
    state = state.copyWith(
      phase: WorkoutPhase.finished,
      isRunning: false,
      remainingMs: 0,
    );
  }

  void _resetCueGuards() {
    _warnFired = false;
    _countdownFired3 = false;
    _countdownFired2 = false;
    _countdownFired1 = false;
  }

}
