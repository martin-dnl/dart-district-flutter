import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/network/api_providers.dart';
import '../controller/match_controller.dart';
import '../controller/ongoing_matches_controller.dart';
import '../data/match_service.dart';
import '../widgets/scoreboard.dart';
import '../widgets/dart_input.dart';
import '../widgets/round_details.dart';

class MatchLiveScreen extends ConsumerStatefulWidget {
  const MatchLiveScreen({super.key});

  @override
  ConsumerState<MatchLiveScreen> createState() => _MatchLiveScreenState();
}

class _MatchLiveScreenState extends ConsumerState<MatchLiveScreen> {
  bool _isRemoteMatch() {
    final match = ref.read(matchControllerProvider);
    return match.inviterId != null || match.inviteeId != null;
  }

  bool _isDoubleOut(String finishType) {
    final normalized = finishType.toLowerCase();
    return normalized == 'doubleout' || normalized == 'double_out';
  }

  Future<int?> _askDoubleAttempts() {
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Checkout Double Out',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Combien de doubles as-tu tentes pour finir ce leg ?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 1),
            child: const Text('1'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 2),
            child: const Text('2'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 3),
            child: const Text('3'),
          ),
        ],
      ),
    );
  }

  String _apiErrorMessage(Object error, String fallback) {
    if (error is! DioException) {
      return fallback;
    }

    String? message;
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final apiError = data['error'];
      if (apiError is String && apiError.trim().isNotEmpty) {
        message = apiError;
      }
    }

    final raw = (message ?? error.message ?? '').toLowerCase();
    if (raw.contains('no throw to undo')) {
      return 'Aucun coup a annuler.';
    }
    if (raw.contains('match is not in progress')) {
      return 'La partie n\'est plus en cours.';
    }
    if (raw.contains('you are not a player')) {
      return 'Vous ne faites pas partie de cette partie.';
    }
    if (raw.contains('player_index does not match current turn')) {
      return 'Le score saisi ne correspond pas au tour en cours.';
    }

    return message ?? fallback;
  }

  Future<void> _submitScore(int score) async {
    final match = ref.read(matchControllerProvider);
    final currentPlayerIndex = match.currentPlayerIndex;
    final currentPlayer = match.players[currentPlayerIndex];
    int? doublesAttempted;

    final isDoubleOutCheckout =
        _isDoubleOut(match.finishType) && score == currentPlayer.score;
    if (isDoubleOutCheckout) {
      doublesAttempted = await _askDoubleAttempts();
      if (doublesAttempted == null) {
        return;
      }
    }

    final isRemoteMatch = _isRemoteMatch();

    if (!isRemoteMatch) {
      ref
          .read(matchControllerProvider.notifier)
          .submitScore(score, doublesAttempted: doublesAttempted);
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      final service = MatchService(api);
      final updated = await service.updateMatchScore(
        matchId: match.id,
        playerIndex: currentPlayerIndex,
        score: score,
        doublesAttempted: doublesAttempted,
      );
      ref.read(matchControllerProvider.notifier).loadMatch(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _apiErrorMessage(e, 'Synchronisation score indisponible.'),
          ),
        ),
      );
    }
  }

  Future<void> _confirmUndo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Annuler le dernier coup ?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Cette action retirera la derniere fleche de la partie.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Oui, annuler',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final isRemoteMatch = _isRemoteMatch();
    if (!isRemoteMatch) {
      ref.read(matchControllerProvider.notifier).undoLastScore();
      return;
    }

    try {
      final match = ref.read(matchControllerProvider);
      final api = ref.read(apiClientProvider);
      final service = MatchService(api);
      final updated = await service.undoLastThrow(match.id);
      ref.read(matchControllerProvider.notifier).loadMatch(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _apiErrorMessage(e, 'Impossible d\'annuler le dernier coup.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<OngoingMatchesState>(ongoingMatchesControllerProvider, (
      _,
      next,
    ) {
      final currentMatch = ref.read(matchControllerProvider);
      final hasRemoteContext =
          currentMatch.inviterId != null || currentMatch.inviteeId != null;
      if (!hasRemoteContext) {
        return;
      }

      for (final candidate in next.matches) {
        if (candidate.id == currentMatch.id) {
          ref.read(matchControllerProvider.notifier).loadMatch(candidate);
          break;
        }
      }
    });

    final match = ref.watch(matchControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${match.mode} · Leg ${match.currentLeg}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: const Text(
                  'Quitter la partie ?',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                content: const Text(
                  'La partie en cours sera perdue.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Continuer'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.pop();
                    },
                    child: const Text(
                      'Quitter',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: _confirmUndo,
            icon: const Icon(Icons.undo, color: AppColors.textSecondary),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scoreboard
            Scoreboard(
              players: match.players,
              currentPlayerIndex: match.currentPlayerIndex,
            ),

            // Round info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Round ${match.currentRound}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    match.players[match.currentPlayerIndex].name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            // Round history
            Expanded(
              child: RoundDetails(
                roundHistory: match.roundHistory,
                players: match.players,
              ),
            ),

            // Score input
            DartInput(
              maxScore: match.players[match.currentPlayerIndex].score,
              onSubmit: _submitScore,
            ),
          ],
        ),
      ),
    );
  }
}
