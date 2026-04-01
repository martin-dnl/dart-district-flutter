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
        color: badge.unlocked ? AppColors.card : AppColors.surface,
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
          Text(
            badge.icon,
            style: TextStyle(
              fontSize: 28,
              color: badge.unlocked ? null : AppColors.textHint,
            ),
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
        ],
      ),
    );
  }
}
