import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/workout_phase.dart';

class ControlBar extends StatelessWidget {
  final WorkoutPhase phase;
  final bool isRunning;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onReset;
  final VoidCallback onSkip;

  const ControlBar({
    super.key,
    required this.phase,
    required this.isRunning,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onReset,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool isIdle =
        phase == WorkoutPhase.idle || phase == WorkoutPhase.finished;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (!isIdle) ...[
            _BigButton(
              icon: Icons.refresh_rounded,
              label: l10n.reset,
              color: Colors.white24,
              onTap: onReset,
            ),
          ],
          _BigButton(
            icon: isIdle
                ? Icons.play_arrow_rounded
                : (isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
            label: isIdle
                ? l10n.start
                : (isRunning ? l10n.pause : l10n.resume),
            color: Colors.white,
            textColor: Colors.black,
            onTap: isIdle
                ? onStart
                : (isRunning ? onPause : onResume),
            large: true,
          ),
          if (!isIdle) ...[
            _BigButton(
              icon: Icons.skip_next_rounded,
              label: l10n.skip,
              color: Colors.white24,
              onTap: onSkip,
            ),
          ],
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  final bool large;

  const _BigButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.textColor = Colors.white,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = large ? 80.0 : 64.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          shape: const CircleBorder(),
          color: color,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: textColor, size: large ? 40 : 30),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
