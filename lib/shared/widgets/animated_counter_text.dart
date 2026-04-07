import 'package:flutter/material.dart';

class AnimatedCounterText extends StatelessWidget {
  const AnimatedCounterText({
    super.key,
    required this.from,
    required this.to,
    required this.duration,
    required this.style,
    this.curve = Curves.easeOutCubic,
    this.prefix = '',
    this.suffix = '',
  });

  final int from;
  final int to;
  final Duration duration;
  final TextStyle style;
  final Curve curve;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: from, end: to),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Text('$prefix$value$suffix', style: style);
      },
    );
  }
}
