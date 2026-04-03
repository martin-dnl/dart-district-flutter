import 'package:flutter/material.dart';

import '../../core/config/app_colors.dart';

class ScoreDisplay extends StatelessWidget {
  final int score;
  final bool animateScoreChange;
  final String playerName;
  final bool isActive;
  final int legsWon;
  final int setsWon;
  final String? averageText;
  final String? checkoutText;

  const ScoreDisplay({
    super.key,
    required this.score,
    this.animateScoreChange = false,
    required this.playerName,
    this.isActive = false,
    this.legsWon = 0,
    this.setsWon = 0,
    this.averageText,
    this.checkoutText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            playerName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _AnimatedScoreNumber(
            score: score,
            animate: animateScoreChange,
            isActive: isActive,
          ),
          const SizedBox(height: 2),
          Text(
            averageText ?? 'Moy. 0.0',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (checkoutText != null) ...[
            const SizedBox(height: 2),
            Text(
              checkoutText!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBadge('Sets: $setsWon'),
              const SizedBox(width: 8),
              _buildBadge('Legs: $legsWon'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }
}

class _AnimatedScoreNumber extends StatefulWidget {
  const _AnimatedScoreNumber({
    required this.score,
    required this.animate,
    required this.isActive,
  });

  final int score;
  final bool animate;
  final bool isActive;

  @override
  State<_AnimatedScoreNumber> createState() => _AnimatedScoreNumberState();
}

class _AnimatedScoreNumberState extends State<_AnimatedScoreNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  late int _displayedScore;
  int _fromScore = 0;
  int _toScore = 0;

  @override
  void initState() {
    super.initState();
    _displayedScore = widget.score;
    _fromScore = widget.score;
    _toScore = widget.score;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addListener(() {
      final value = (_fromScore + (_toScore - _fromScore) * _animation.value)
          .round();
      if (value != _displayedScore && mounted) {
        setState(() {
          _displayedScore = value;
        });
      }
    });
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedScoreNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.score == oldWidget.score) {
      return;
    }

    final shouldAnimate =
        widget.animate && widget.score < oldWidget.score && widget.score > 0;
    if (!shouldAnimate) {
      _controller.stop();
      setState(() {
        _displayedScore = widget.score;
      });
      return;
    }

    _fromScore = oldWidget.score;
    _toScore = widget.score;
    _controller
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '$_displayedScore',
      style: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: widget.isActive ? AppColors.primary : AppColors.textPrimary,
      ),
    );
  }
}
