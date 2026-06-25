import '../models/workout_phase.dart';
import '../models/timer_config.dart';

class TimerState {
  final WorkoutPhase phase;
  final int currentRound;
  final int remainingMs;
  final int totalPhaseMs;
  final bool isRunning;
  final TimerConfig config;

  const TimerState({
    required this.phase,
    required this.currentRound,
    required this.remainingMs,
    required this.totalPhaseMs,
    required this.isRunning,
    required this.config,
  });

  factory TimerState.idle(TimerConfig config) => TimerState(
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

  TimerState copyWith({
    WorkoutPhase? phase,
    int? currentRound,
    int? remainingMs,
    int? totalPhaseMs,
    bool? isRunning,
    TimerConfig? config,
  }) {
    return TimerState(
      phase: phase ?? this.phase,
      currentRound: currentRound ?? this.currentRound,
      remainingMs: remainingMs ?? this.remainingMs,
      totalPhaseMs: totalPhaseMs ?? this.totalPhaseMs,
      isRunning: isRunning ?? this.isRunning,
      config: config ?? this.config,
    );
  }
}
