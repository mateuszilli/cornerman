import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../l10n/app_localizations.dart';
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
    final notifier = ref.watch(timerProvider);
    final s = notifier.state;

    // Manage wakelock in response to state changes.
    if (s.config.keepScreenAwake && s.isRunning) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }

    final l10n = AppLocalizations.of(context)!;
    final phaseColor = s.phase.color;

    return Scaffold(
      backgroundColor: phaseColor,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              phase: s.phase,
              currentRound: s.currentRound,
              totalRounds: s.config.rounds,
              l10n: l10n,
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
                      child: _LiveCountdown(
                        notifier: notifier,
                        phaseLabel: _phaseLabel(l10n, s.phase),
                        warningSeconds: s.config.warningSeconds,
                        isWarningPhase: s.phase == WorkoutPhase.round,
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

String _phaseLabel(AppLocalizations l10n, WorkoutPhase phase) =>
    switch (phase) {
      WorkoutPhase.idle => l10n.phaseReady,
      WorkoutPhase.prep => l10n.phaseGetReady,
      WorkoutPhase.round => l10n.phaseFight,
      WorkoutPhase.rest => l10n.phaseRest,
      WorkoutPhase.finished => l10n.phaseDone,
    };

/// The only part of the screen that updates on every tick. Listens directly
/// to [TimerNotifier]'s per-tick `ValueNotifier`s instead of `ref.watch`, so
/// a tick repaints just the ring (via its own `RepaintBoundary`) and the
/// digits (only when the displayed second actually changes) — nothing else
/// in the widget tree rebuilds.
class _LiveCountdown extends StatelessWidget {
  final TimerNotifier notifier;
  final String phaseLabel;
  final int warningSeconds;
  final bool isWarningPhase;

  const _LiveCountdown({
    required this.notifier,
    required this.phaseLabel,
    required this.warningSeconds,
    required this.isWarningPhase,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: notifier.progressNotifier,
      builder: (context, progress, child) {
        return RepaintBoundary(
          child: ProgressRing(
            progress: progress,
            color: Colors.white,
            strokeWidth: 12,
            child: child!,
          ),
        );
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ValueListenableBuilder<int>(
                valueListenable: notifier.remainingSecondsNotifier,
                builder: (context, remainingSeconds, _) => CountdownDisplay(
                  remainingMs: remainingSeconds * 1000,
                  pulsing: isWarningPhase &&
                      warningSeconds > 0 &&
                      remainingSeconds <= warningSeconds &&
                      remainingSeconds > 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              phaseLabel,
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
    );
  }
}

class _TopBar extends StatelessWidget {
  final WorkoutPhase phase;
  final int currentRound;
  final int totalRounds;
  final AppLocalizations l10n;
  final VoidCallback onSettings;

  const _TopBar({
    required this.phase,
    required this.currentRound,
    required this.totalRounds,
    required this.l10n,
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
              l10n.roundCounter(currentRound, totalRounds),
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
            tooltip: l10n.settingsTooltip,
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}
