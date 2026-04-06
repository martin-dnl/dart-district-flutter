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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
          const SizedBox(height: 6),
          _AnimatedScoreNumber(
            score: score,
            animate: animateScoreChange,
            isActive: isActive,
          ),
          const SizedBox(height: 1),
          Text(
            averageText ?? 'Moy. 0.0',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 14,
            child: Align(
              alignment: Alignment.center,
              child: checkoutText == null
                  ? null
                  : Text(
                      checkoutText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
            const SizedBox(height: 6),
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
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late int _displayedScore;
  int _fromScore = 0;
  int _toScore = 0;

  @override
  void initState() {
    super.initState();
    _displayedScore = widget.score;
    _fromScore = widget.score;
    _toScore = widget.score;
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 700),
        )..addListener(() {
          final value =
              (_fromScore + (_toScore - _fromScore) * _animation.value).round();
          if (value != _displayedScore && mounted) {
            setState(() {
              _displayedScore = value;
            });
          }
        });
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.06,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.06,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 80,
      ),
    ]).animate(_controller);
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.0,
          end: 0.6,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.6,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 80,
      ),
    ]).animate(_controller);
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
      _controller.value = 0;
      setState(() {
        _displayedScore = widget.score;
      });
      return;
    }

    _fromScore = oldWidget.score;
    _toScore = widget.score;
    final delta = (_fromScore - _toScore).abs();
    final durationMs = (520 + (delta * 3)).clamp(520, 1200);
    _controller.duration = Duration(milliseconds: durationMs);
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = widget.isActive ? _scaleAnimation.value : 1.0;
        final glow = widget.isActive ? _glowAnimation.value : 0.0;
        final baseColor = widget.isActive
            ? AppColors.primary
            : AppColors.textPrimary;

        return Transform.scale(
          scale: scale,
          child: Text(
            '$_displayedScore',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: baseColor,
              shadows: [
                Shadow(
                  color: AppColors.primary.withValues(alpha: glow),
                  blurRadius: 6 + (14 * glow),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
