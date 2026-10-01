import 'timer_config.dart';
import 'workout_phase.dart';

enum CueType { preFinish, finish, preStart, start, beep, workoutEnd }

/// A cue fires once, at an exact offset from workout t=0.
class CueEvent {
  final CueType type;
  final Duration at;
  final int seq; // tie-breaker for cues that land on the same instant

  const CueEvent({required this.type, required this.at, required this.seq});
}

/// One phase's span on the workout timeline, as an offset range from t=0.
class PhaseSpan {
  final WorkoutPhase phase;
  final int roundNumber;
  final Duration start;
  final Duration end;

  const PhaseSpan({
    required this.phase,
    required this.roundNumber,
    required this.start,
    required this.end,
  });

  Duration get duration => end - start;
}

/// The immutable, precomputed timeline for a full workout: every phase's
/// start/end offset and every cue's exact fire offset. Built once at start
/// (and recomputed on config change); the single source of truth for both
/// the UI and the audio system.
class WorkoutSchedule {
  final List<PhaseSpan> spans;
  final List<CueEvent> cues; // sorted ascending by (at, seq)
  final Duration totalDuration;

  const WorkoutSchedule({
    required this.spans,
    required this.cues,
    required this.totalDuration,
  });

  factory WorkoutSchedule.build(TimerConfig cfg) {
    final spans = <PhaseSpan>[];
    final cues = <CueEvent>[];
    var seq = 0;
    var cursor = Duration.zero;

    void addCue(CueType type, Duration at) {
      cues.add(CueEvent(type: type, at: at, seq: seq++));
    }

    // Pre-start warning + countdown beeps shared by prep and rest phases.
    void addLeadInCues(Duration start, Duration end) {
      final durSecs = (end - start).inSeconds;
      if (cfg.warningSeconds > 0 && cfg.warningSeconds <= durSecs) {
        addCue(CueType.preStart, end - Duration(seconds: cfg.warningSeconds));
      }
      if (cfg.countdownBeeps) {
        for (final n in const [3, 2, 1]) {
          if (n <= durSecs) {
            addCue(CueType.beep, end - Duration(seconds: n));
          }
        }
      }
    }

    if (cfg.prepSeconds > 0) {
      final end = cursor + Duration(seconds: cfg.prepSeconds);
      spans.add(PhaseSpan(
        phase: WorkoutPhase.prep,
        roundNumber: 0,
        start: cursor,
        end: end,
      ));
      addLeadInCues(cursor, end);
      cursor = end;
    }

    for (var round = 1; round <= cfg.rounds; round++) {
      final roundEnd = cursor + Duration(seconds: cfg.roundSeconds);
      spans.add(PhaseSpan(
        phase: WorkoutPhase.round,
        roundNumber: round,
        start: cursor,
        end: roundEnd,
      ));
      addCue(CueType.start, cursor);
      if (cfg.warningSeconds > 0 && cfg.warningSeconds <= cfg.roundSeconds) {
        addCue(CueType.preFinish, roundEnd - Duration(seconds: cfg.warningSeconds));
      }
      addCue(CueType.finish, roundEnd);
      cursor = roundEnd;

      if (round < cfg.rounds) {
        final restEnd = cursor + Duration(seconds: cfg.restSeconds);
        spans.add(PhaseSpan(
          phase: WorkoutPhase.rest,
          roundNumber: round,
          start: cursor,
          end: restEnd,
        ));
        addLeadInCues(cursor, restEnd);
        cursor = restEnd;
      }
    }

    addCue(CueType.workoutEnd, cursor);
    cues.sort((a, b) {
      final byTime = a.at.compareTo(b.at);
      return byTime != 0 ? byTime : a.seq.compareTo(b.seq);
    });

    return WorkoutSchedule(spans: spans, cues: cues, totalDuration: cursor);
  }

  PhaseSpan spanAt(Duration elapsed) {
    for (final s in spans) {
      if (elapsed < s.end) return s;
    }
    return spans.last;
  }
}
