import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/network/api_providers.dart';
import '../controller/match_controller.dart';
import '../controller/ongoing_matches_controller.dart';
import '../data/match_service.dart';
import '../models/match_model.dart';
import '../widgets/scoreboard.dart';
import '../widgets/dart_input.dart';
import '../widgets/round_details.dart';

class MatchLiveScreen extends ConsumerStatefulWidget {
  const MatchLiveScreen({super.key});

  @override
  ConsumerState<MatchLiveScreen> createState() => _MatchLiveScreenState();
}

class _MatchLiveScreenState extends ConsumerState<MatchLiveScreen> {
  bool _didShowEndDialog = false;

  bool _isRemoteMatch() {
    final match = ref.read(matchControllerProvider);
    return match.inviterId != null || match.inviteeId != null;
  }

  bool _isDoubleOut(String finishType) {
    final normalized = finishType.toLowerCase();
    return normalized == 'doubleout' || normalized == 'double_out';
  }

  Future<int?> _askDoubleAttempts() {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Checkout !',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Combien de doubles tentes pour finir ?',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [0, 1, 2, 3]
                    .map(
                      (n) => GestureDetector(
                        onTap: () => Navigator.pop(ctx, n),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.surfaceLight),
                          ),
                          child: Center(
                            child: Text(
                              '$n',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
              ),
            ],
          ),
        ),
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
      if (doublesAttempted < 0 || doublesAttempted > 3) {
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

  Future<void> _confirmAbandon() async {
    final match = ref.read(matchControllerProvider);
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (ctx) => _AbandonSheet(players: match.players),
    );

    if (result == null) {
      return;
    }
    await _processAbandon(result);
  }

  Future<void> _processAbandon(int abandoningPlayerIndex) async {
    final isRemoteMatch = _isRemoteMatch();
    if (!isRemoteMatch) {
      ref
          .read(matchControllerProvider.notifier)
          .abandonMatch(abandoningPlayerIndex);
      return;
    }

    try {
      final match = ref.read(matchControllerProvider);
      final api = ref.read(apiClientProvider);
      final service = MatchService(api);
      final updated = await service.abandonMatch(
        matchId: match.id,
        surrenderedByIndex: abandoningPlayerIndex,
      );
      ref.read(matchControllerProvider.notifier).loadMatch(updated);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _apiErrorMessage(e, 'Impossible d\'abandonner la partie.'),
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

  Future<void> _showEndOfMatchDialog(MatchModel match) async {
    if (_didShowEndDialog || !mounted) {
      return;
    }
    _didShowEndDialog = true;

    final shouldOpenReport = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Match termine',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Consulter le rapport de match ? ',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Voir le rapport'),
          ),
        ],
      ),
    );

    if (!mounted) {
      return;
    }

    if (shouldOpenReport == true) {
      final reportPath = AppRoutes.matchReport.replaceFirst(':id', match.id);
      context.pushReplacement(reportPath, extra: match);
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

    if (match.status == MatchStatus.finished && !_didShowEndDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEndOfMatchDialog(match);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          match.setsToWin == 1
              ? '${match.mode} · Leg ${match.currentLeg}'
              : '${match.mode} · Set ${match.currentSet} · Leg ${match.currentLeg}',
        ),
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
            onPressed: () {
              Clipboard.setData(ClipboardData(text: match.id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'ID du match copie. Partagez-le pour inviter un spectateur.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.visibility, color: AppColors.textSecondary),
            tooltip: 'Inviter un spectateur',
          ),
          IconButton(
            onPressed: _confirmAbandon,
            icon: const Icon(Icons.flag_outlined, color: AppColors.warning),
            tooltip: 'Abandonner',
          ),
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
              finishType: match.finishType,
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

class _AbandonSheet extends StatefulWidget {
  const _AbandonSheet({required this.players});

  final List<PlayerMatch> players;

  @override
  State<_AbandonSheet> createState() => _AbandonSheetState();
}

class _AbandonSheetState extends State<_AbandonSheet> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Qui abandonne ?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(widget.players.length, (index) {
              final player = widget.players[index];
              final isSelected = _selectedIndex == index;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                title: Text(
                  player.name,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: _selectedIndex == null
                    ? null
                    : () => Navigator.pop(context, _selectedIndex),
                child: const Text('Confirmer l\'abandon'),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
