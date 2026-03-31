import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../../../shared/widgets/score_display.dart';
import '../models/match_model.dart';

class Scoreboard extends StatelessWidget {
  final List<PlayerMatch> players;
  final int currentPlayerIndex;

  const Scoreboard({
    super.key,
    required this.players,
    required this.currentPlayerIndex,
  });

  String _doubleStats(PlayerMatch player) {
    final attempted = player.doublesAttempted;
    final hit = player.doublesHit;
    if (attempted <= 0) {
      return 'Dbl 0/0';
    }

    final rate = (hit / attempted) * 100;
    return 'Dbl $hit/$attempted (${rate.toStringAsFixed(0)}%)';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Player 1
          Expanded(
            child: ScoreDisplay(
              playerName: players[0].name,
              score: players[0].score,
              isActive: currentPlayerIndex == 0,
              legsWon: players[0].legsWon,
              setsWon: players[0].setsWon,
            ),
          ),

          // VS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                const Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 8),
                // Average display
                Column(
                  children: [
                    Text(
                      players[0].average.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                    const Text(
                      'avg',
                      style: TextStyle(fontSize: 9, color: AppColors.textHint),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _doubleStats(players[0]),
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white
                      ),
                    ),
                    const Divider(height: 8),
                    Text(
                      players.length > 1
                          ? players[1].average.toStringAsFixed(1)
                          : '0.0',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      players.length > 1 ? _doubleStats(players[1]) : 'Dbl 0/0',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Player 2
          if (players.length > 1)
            Expanded(
              child: ScoreDisplay(
                playerName: players[1].name,
                score: players[1].score,
                isActive: currentPlayerIndex == 1,
                legsWon: players[1].legsWon,
                setsWon: players[1].setsWon,
              ),
            ),
        ],
      ),
    );
  }
}
