import 'package:flutter/material.dart';

class CountdownDisplay extends StatelessWidget {
  final int remainingMs;
  final bool pulsing;

  const CountdownDisplay({
    super.key,
    required this.remainingMs,
    this.pulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    final totalSecs = (remainingMs / 1000).ceil().clamp(0, 99 * 60 + 59);
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    final text = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return LayoutBuilder(builder: (context, constraints) {
      final fontSize = constraints.maxWidth * 0.28;
      final style = TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: -2,
        shadows: const [
          Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(2, 4)),
        ],
      );

      if (!pulsing) {
        return Text(text, style: style);
      }

      return _PulseAnimation(child: Text(text, style: style));
    });
  }
}

class _PulseAnimation extends StatefulWidget {
  final Widget child;
  const _PulseAnimation({required this.child});

  @override
  State<_PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<_PulseAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
