import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../models/match_model.dart';

class RoundDetails extends StatelessWidget {
  final List<RoundScore> roundHistory;
  final List<PlayerMatch> players;

  const RoundDetails({
    super.key,
    required this.roundHistory,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    if (roundHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gps_fixed, size: 48, color: AppColors.textHint),
            SizedBox(height: 12),
            Text(
              'Entrez votre score',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            SizedBox(height: 4),
            Text(
              'Le total de vos 3 fléchettes',
              style: TextStyle(fontSize: 13, color: AppColors.textHint),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: roundHistory.length,
      reverse: true,
      itemBuilder: (context, index) {
        final reversedIndex = roundHistory.length - 1 - index;
        final round = roundHistory[reversedIndex];
        final isPlayer1 = round.playerIndex == 0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              // Player 1 side
              Expanded(
                child: isPlayer1
                    ? _RoundBadge(
                        score: round.total,
                        isHighlight: round.total >= 100,
                        isBust: round.isBust,
                      )
                    : const SizedBox.shrink(),
              ),

              // Round number
              Container(
                width: 36,
                alignment: Alignment.center,
                child: Text(
                  'R${round.round}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ),

              // Player 2 side
              Expanded(
                child: !isPlayer1
                    ? _RoundBadge(
                        score: round.total,
                        isHighlight: round.total >= 100,
                        isBust: round.isBust,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoundBadge extends StatelessWidget {
  final int score;
  final bool isHighlight;
  final bool isBust;

  const _RoundBadge({
    required this.score,
    this.isHighlight = false,
    this.isBust = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isBust
            ? AppColors.error.withValues(alpha: 0.14)
            : isHighlight
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: isBust
            ? Border.all(
                color: AppColors.error.withValues(alpha: 0.5),
                width: 1,
              )
            : isHighlight
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: Text(
        isBust ? 'BUST !' : '$score',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isBust
              ? AppColors.error
              : isHighlight
              ? AppColors.primary
              : AppColors.textPrimary,
        ),
      ),
    );
  }
}
