import 'timer_config.dart';

/// The only mutable state a running workout has. No countdown, no
/// "remaining time" field — everything else is derived from this plus a
/// wall-clock timestamp via `resolve()`.
class WorkoutState {
  final TimerConfig config;
  final DateTime? startedAt; // null = idle, never started
  final Duration pausedOffset; // total time spent paused so far
  final DateTime? pausedAt; // non-null while currently paused
  final Duration skipOffset; // accumulated manual skips, added to elapsed time

  const WorkoutState({
    required this.config,
    this.startedAt,
    this.pausedOffset = Duration.zero,
    this.pausedAt,
    this.skipOffset = Duration.zero,
  });

  factory WorkoutState.idle(TimerConfig config) => WorkoutState(config: config);

  bool get isIdle => startedAt == null;
  bool get isPaused => pausedAt != null;

  WorkoutState copyWith({
    TimerConfig? config,
    DateTime? startedAt,
    Duration? pausedOffset,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    Duration? skipOffset,
  }) {
    return WorkoutState(
      config: config ?? this.config,
      startedAt: startedAt ?? this.startedAt,
      pausedOffset: pausedOffset ?? this.pausedOffset,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      skipOffset: skipOffset ?? this.skipOffset,
    );
  }

  /// Elapsed workout time at [now], clamped to non-negative. Pure function
  /// of state + now — no side effects, no internal clock reads.
  Duration elapsedAt(DateTime now) {
    if (startedAt == null) return Duration.zero;
    final upTo = pausedAt ?? now;
    final raw = upTo.difference(startedAt!) - pausedOffset + skipOffset;
    return raw < Duration.zero ? Duration.zero : raw;
  }
}
