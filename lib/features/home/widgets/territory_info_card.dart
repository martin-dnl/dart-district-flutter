import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';

class TerritoryInfoCard extends StatelessWidget {
  const TerritoryInfoCard({
    super.key,
    required this.conflictsNearby,
    required this.conqueredCount,
    required this.conflictCount,
    required this.availableCount,
  });

  final int conflictsNearby;
  final int conqueredCount;
  final int conflictCount;
  final int availableCount;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.territoryConquered.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.flag,
                  color: AppColors.territoryConquered,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Guerre de Territoire',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '$conflictsNearby zones en conflit près de vous',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Territory stats
          Row(
            children: [
              _TerritoryBadge(
                color: AppColors.territoryConquered,
                label: 'Conquises',
                count: '$conqueredCount',
              ),
              const SizedBox(width: 12),
              _TerritoryBadge(
                color: AppColors.territoryConflict,
                label: 'En conflit',
                count: '$conflictCount',
              ),
              const SizedBox(width: 12),
              _TerritoryBadge(
                color: AppColors.territoryAvailable,
                label: 'Disponibles',
                count: '$availableCount',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TerritoryBadge extends StatelessWidget {
  final Color color;
  final String label;
  final String count;

  const _TerritoryBadge({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
