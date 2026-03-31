import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';

class RankingList extends StatelessWidget {
  const RankingList({
    super.key,
    required this.clubs,
  });

  final List<Map<String, dynamic>> clubs;

  @override
  Widget build(BuildContext context) {
    final resolvedClubs = clubs.isEmpty
        ? const [
            {
              'rank': 1,
              'name': 'Aucun club',
              'conquest_points': 0,
            }
          ]
        : clubs;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: resolvedClubs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final club = resolvedClubs[index];
        final rank = (club['rank'] as num?)?.toInt() ?? index + 1;
        final points = (club['conquest_points'] as num?)?.toInt() ?? 0;
        final isTop = rank == 1;

        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 32,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isTop ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Club icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isTop
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.groups,
                  color: isTop ? AppColors.accent : AppColors.textHint,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),

              // Name
              Expanded(
                child: Text(
                  (club['name'] ?? 'Club').toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              // Zones
              Text(
                '$points pts',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
