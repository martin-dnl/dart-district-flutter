import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_routes.dart';
import '../../../core/config/app_colors.dart';
import '../../match/controller/match_controller.dart';
import '../../match/controller/ongoing_matches_controller.dart';
import '../../match/models/match_model.dart';

class OngoingMatchesTile extends ConsumerWidget {
  const OngoingMatchesTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ongoingMatches = ref.watch(ongoingMatchesControllerProvider);

    if (ongoingMatches.matches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Text(
            'Matchs en cours',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...ongoingMatches.matches.map((match) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _MatchCard(match: match),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _MatchCard extends ConsumerWidget {
  const _MatchCard({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player1 = match.players[0];
    final player2 = match.players[1];
    final isPlayer1Turn = match.currentPlayerIndex == 0;

    return GestureDetector(
      onTap: () {
        ref.read(matchControllerProvider.notifier).loadMatch(match);
        context.push(_routeForMatch(match));
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode and current leg/set info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mode: ${match.mode}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Leg ${match.currentLeg} / Set ${match.currentSet}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Players and scores
            _PlayerScoreRow(
              playerName: player1.name,
              score: player1.score,
              legsWon: player1.legsWon,
              isTurn: isPlayer1Turn,
            ),
            const SizedBox(height: 8),
            _PlayerScoreRow(
              playerName: player2.name,
              score: player2.score,
              legsWon: player2.legsWon,
              isTurn: !isPlayer1Turn,
            ),
            const SizedBox(height: 10),
            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(matchControllerProvider.notifier).loadMatch(match);
                  context.push(_routeForMatch(match));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text(
                  'Continuer',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _routeForMatch(MatchModel match) {
    final mode = match.mode.trim().toLowerCase();
    if (mode == 'cricket') {
      return AppRoutes.matchCricket;
    }
    if (mode == 'chasseur') {
      return _hasChasseurZonesSelected(match)
          ? AppRoutes.matchChasseur
          : AppRoutes.matchChasseurZones;
    }
    return AppRoutes.matchLive;
  }

  bool _hasChasseurZonesSelected(MatchModel match) {
    final picked = <int>{};
    for (final round in match.roundHistory) {
      final label = round.dartPositions.isNotEmpty
          ? (round.dartPositions.first.label ?? '')
          : '';
      final selection = RegExp(r'^Z:([1-9]|1[0-9]|20|25)$').firstMatch(label);
      if (selection != null) {
        picked.add(round.playerIndex);
      }
    }
    return picked.length >= 2;
  }
}

class _PlayerScoreRow extends StatelessWidget {
  const _PlayerScoreRow({
    required this.playerName,
    required this.score,
    required this.legsWon,
    required this.isTurn,
  });

  final String playerName;
  final int score;
  final int legsWon;
  final bool isTurn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isTurn
            ? AppColors.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              playerName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isTurn ? AppColors.primary : AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$score',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Legs: $legsWon',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
