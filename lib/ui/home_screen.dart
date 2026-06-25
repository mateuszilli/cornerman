import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/workout_phase.dart';
import '../state/timer_notifier.dart';
import 'config_screen.dart';
import 'widgets/control_bar.dart';
import 'widgets/countdown_display.dart';
import 'widgets/progress_ring.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(timerProvider);
    final notifier = ref.read(timerProvider.notifier);

    // Manage wakelock in response to state changes.
    if (s.config.keepScreenAwake && s.isRunning) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }

    final phaseColor = s.phase.color;
    final isWarning = s.isWarning;

    return Scaffold(
      backgroundColor: phaseColor,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              phase: s.phase,
              currentRound: s.currentRound,
              totalRounds: s.config.rounds,
              onSettings: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConfigScreen()),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: ProgressRing(
                        progress: s.progress,
                        color: Colors.white,
                        strokeWidth: 12,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                child: CountdownDisplay(
                                  remainingMs: s.remainingMs,
                                  pulsing: isWarning,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                s.phase.label,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ControlBar(
              phase: s.phase,
              isRunning: s.isRunning,
              onStart: notifier.start,
              onPause: notifier.pause,
              onResume: notifier.resume,
              onReset: notifier.reset,
              onSkip: notifier.skipPhase,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final WorkoutPhase phase;
  final int currentRound;
  final int totalRounds;
  final VoidCallback onSettings;

  const _TopBar({
    required this.phase,
    required this.currentRound,
    required this.totalRounds,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final showRound = phase == WorkoutPhase.round ||
        phase == WorkoutPhase.rest ||
        phase == WorkoutPhase.prep;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showRound)
            Text(
              'ROUND  $currentRound / $totalRounds',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            )
          else
            const SizedBox(),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 28),
            tooltip: 'Settings',
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}
