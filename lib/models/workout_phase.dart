import 'package:flutter/material.dart';

enum WorkoutPhase { idle, prep, round, rest, finished }

extension WorkoutPhaseX on WorkoutPhase {
  Color get color {
    switch (this) {
      case WorkoutPhase.idle:
        return const Color(0xFF212121);
      case WorkoutPhase.prep:
        return const Color(0xFF1565C0);
      case WorkoutPhase.round:
        return const Color(0xFF2E7D32);
      case WorkoutPhase.rest:
        return const Color(0xFFE65100);
      case WorkoutPhase.finished:
        return const Color(0xFF4A148C);
    }
  }
}
