import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../../../shared/models/match_history_summary.dart';
import '../../../shared/widgets/glass_card.dart';

class MatchHistoryTile extends StatelessWidget {
  final MatchHistorySummary match;

  const MatchHistoryTile({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Result indicator
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: match.won ? AppColors.success : AppColors.error,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Match details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'vs ${match.opponentName}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        match.mode,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(match.playedAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),

          // Score & ELO
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                match.setsScore,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: match.won ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(height: 2),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inHours < 1) return 'A l\'instant';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays == 1) return 'Hier';
    return 'Il y a ${diff.inDays}j';
  }
}
