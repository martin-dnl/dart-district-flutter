import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';

class RecentMatchesList extends StatelessWidget {
  const RecentMatchesList({
    super.key,
    required this.matches,
  });

  final List<RecentMatchData> matches;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: matches.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final match = matches[index];
        return _MatchTile(match: match);
      },
    );
  }
}

class RecentMatchData {
  final String opponent;
  final String mode;
  final String result;
  final String score;
  final String date;
  final bool won;

  const RecentMatchData({
    required this.opponent,
    required this.mode,
    required this.result,
    required this.score,
    required this.date,
    required this.won,
  });
}

class _MatchTile extends StatelessWidget {
  final RecentMatchData match;

  const _MatchTile({required this.match});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Result indicator
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: match.won ? AppColors.success : AppColors.error,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Match info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'vs ${match.opponent}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  match.mode,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                match.score,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: match.won ? AppColors.success : AppColors.error,
                ),
              ),
              Text(
                match.date,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
