import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../models/bracket_match_model.dart';

class BracketView extends StatelessWidget {
  const BracketView({super.key, required this.matches});

  final List<BracketMatchModel> matches;

  @override
  Widget build(BuildContext context) {
    final rounds = <int, List<BracketMatchModel>>{};
    for (final match in matches) {
      rounds
          .putIfAbsent(match.roundNumber, () => <BracketMatchModel>[])
          .add(match);
    }

    final sortedKeys = rounds.keys.toList()..sort((a, b) => b.compareTo(a));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sortedKeys.map((key) {
            final roundMatches = rounds[key]!
              ..sort((a, b) => a.position.compareTo(b.position));
            return Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _roundLabel(key),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...roundMatches.map(
                    (match) => Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _BracketMatchCard(match: match),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _roundLabel(int roundNumber) {
    switch (roundNumber) {
      case 1:
        return 'Finale';
      case 2:
        return 'Demies';
      case 4:
        return 'Quarts';
      case 8:
        return 'Huitiemes';
      case 16:
        return 'Seiziemes';
      default:
        return 'Round $roundNumber';
    }
  }
}

class _BracketMatchCard extends StatelessWidget {
  const _BracketMatchCard({required this.match});

  final BracketMatchModel match;

  @override
  Widget build(BuildContext context) {
    final borderColor = match.isInProgress
        ? AppColors.primary
        : match.isCompleted
        ? AppColors.success
        : AppColors.stroke;

    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: CustomPaint(
        painter: _ConnectionPainter(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            children: [
              _line(
                name: match.player1Name ?? '-',
                isWinner:
                    match.winnerId != null && match.winnerId == match.player1Id,
              ),
              const Divider(color: AppColors.stroke, height: 12),
              _line(
                name: match.player2Name ?? '-',
                isWinner:
                    match.winnerId != null && match.winnerId == match.player2Id,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line({required String name, required bool isWinner}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: name == '-' ? AppColors.textHint : AppColors.textPrimary,
              fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.stroke.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width, size.height / 2),
      Offset(size.width + 10, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
