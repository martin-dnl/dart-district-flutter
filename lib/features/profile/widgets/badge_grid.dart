import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../controller/profile_controller.dart';

class BadgeGrid extends StatelessWidget {
  final List<AchievementBadge> badges;
  final int? maxDisplay;

  const BadgeGrid({super.key, required this.badges, this.maxDisplay});

  @override
  Widget build(BuildContext context) {
    final displayed = maxDisplay == null
        ? badges
        : badges.take(maxDisplay!).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: displayed.length,
      itemBuilder: (context, index) {
        final badge = displayed[index];
        return _BadgeItem(badge: badge);
      },
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final AchievementBadge badge;

  const _BadgeItem({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badge.unlocked
            ? AppColors.card
            : AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badge.unlocked
              ? AppColors.accent.withValues(alpha: 0.3)
              : AppColors.surfaceLight,
          width: badge.unlocked ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge.difficulty,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              ColorFiltered(
                colorFilter: badge.unlocked
                    ? const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.multiply,
                      )
                    : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                child: _BadgeVisual(icon: badge.icon),
              ),
              if (!badge.unlocked)
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: AppColors.textHint.withValues(alpha: 0.85),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: badge.unlocked
                  ? AppColors.textPrimary
                  : AppColors.textHint,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Icon(
            badge.unlocked
                ? Icons.verified_rounded
                : Icons.lock_outline_rounded,
            size: 14,
            color: badge.unlocked ? AppColors.success : AppColors.textHint,
          ),
        ],
      ),
    );
  }
}

class _BadgeVisual extends StatelessWidget {
  const _BadgeVisual({required this.icon});

  final String icon;

  bool get _isRemote =>
      icon.startsWith('http://') || icon.startsWith('https://');

  bool get _looksLikeAssetPath {
    return icon.contains('/') &&
        (icon.endsWith('.png') ||
            icon.endsWith('.jpg') ||
            icon.endsWith('.jpeg') ||
            icon.endsWith('.webp') ||
            icon.endsWith('.gif'));
  }

  @override
  Widget build(BuildContext context) {
    if (_isRemote) {
      return Image.network(
        icon,
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Text('🏅', style: TextStyle(fontSize: 28)),
      );
    }

    if (_looksLikeAssetPath) {
      return Image.asset(
        icon,
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Text('🏅', style: TextStyle(fontSize: 28)),
      );
    }

    return Text(icon, style: const TextStyle(fontSize: 28));
  }
}
