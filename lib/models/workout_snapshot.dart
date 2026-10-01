import 'timer_config.dart';
import 'workout_phase.dart';
import 'workout_schedule.dart';
import 'workout_state.dart';

/// Everything the UI needs to render a single instant, derived from
/// [WorkoutState] + [WorkoutSchedule] + a wall-clock timestamp.
class WorkoutSnapshot {
  final WorkoutPhase phase;
  final int currentRound;
  final int remainingMs;
  final int totalPhaseMs;
  final bool isRunning;
  final TimerConfig config;

  const WorkoutSnapshot({
    required this.phase,
    required this.currentRound,
    required this.remainingMs,
    required this.totalPhaseMs,
    required this.isRunning,
    required this.config,
  });

  factory WorkoutSnapshot.idle(TimerConfig config) => WorkoutSnapshot(
        phase: WorkoutPhase.idle,
        currentRound: 0,
        remainingMs: config.roundSeconds * 1000,
        totalPhaseMs: config.roundSeconds * 1000,
        isRunning: false,
        config: config,
      );

  double get progress =>
      totalPhaseMs == 0 ? 0 : 1 - (remainingMs / totalPhaseMs);

  int get remainingSeconds => (remainingMs / 1000).ceil();

  bool get isWarning =>
      phase == WorkoutPhase.round &&
      remainingSeconds <= config.warningSeconds &&
      remainingSeconds > 0;
}

/// Pure, synchronous, allocation-light: computes elapsed wall-clock time,
/// subtracts paused time and skip offsets, then walks the precomputed
/// schedule to determine exactly where the workout is. No dependency on
/// `DateTime.now()` internally — `now` is always injected.
WorkoutSnapshot resolve(WorkoutState state, WorkoutSchedule schedule, DateTime now) {
  if (state.isIdle) {
    return WorkoutSnapshot.idle(state.config);
  }

  final rawElapsed = state.elapsedAt(now);
  final elapsed =
      rawElapsed > schedule.totalDuration ? schedule.totalDuration : rawElapsed;

  if (elapsed >= schedule.totalDuration) {
    final lastRound = schedule.spans.lastWhere(
      (s) => s.phase == WorkoutPhase.round,
      orElse: () => schedule.spans.last,
    );
    return WorkoutSnapshot(
      phase: WorkoutPhase.finished,
      currentRound: state.config.rounds,
      remainingMs: 0,
      totalPhaseMs: lastRound.duration.inMilliseconds,
      isRunning: false,
      config: state.config,
    );
  }

  final span = schedule.spanAt(elapsed);
  final remaining = span.end - elapsed;

  return WorkoutSnapshot(
    phase: span.phase,
    currentRound: span.roundNumber,
    remainingMs: remaining.inMilliseconds,
    totalPhaseMs: span.duration.inMilliseconds,
    isRunning: !state.isPaused,
    config: state.config,
  );
}
