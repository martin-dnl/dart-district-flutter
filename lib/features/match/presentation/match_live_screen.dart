import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/network/api_providers.dart';
import '../../auth/controller/auth_controller.dart';
import '../../home/controller/recent_ranked_matches_provider.dart';
import '../../profile/controller/profile_controller.dart';
import '../data/checkout_chart.dart';
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
  final Set<int> _animatedPlayerIndexes = <int>{};
  static const String _scoreModeSettingKey = 'GAME_OPTION.SCORE_MODE';
  static const String _manualScoreMode = 'MANUAL';
  String _scoreMode = _manualScoreMode;

  bool _isRemoteMatch() {
    final match = ref.read(matchControllerProvider);
    return match.inviterId != null || match.inviteeId != null;
  }

  bool _isDoubleOut(String finishType) {
    final normalized = finishType.toLowerCase();
    return normalized == 'doubleout' || normalized == 'double_out';
  }

  bool _isX01Mode(String mode) {
    return mode == '301' || mode == '501' || mode == '701';
  }

  @override
  void initState() {
    super.initState();
    _loadScoreMode();
  }

  Future<void> _loadScoreMode() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get<Map<String, dynamic>>(
        '/users/me/settings',
        queryParameters: {'key': _scoreModeSettingKey},
      );
      final raw = response.data ?? const <String, dynamic>{};
      final data = raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
      final value = (data['value'] ?? '').toString().trim();
      if (!mounted) {
        return;
      }
      setState(() {
        _scoreMode = value.isEmpty ? _manualScoreMode : value;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scoreMode = _manualScoreMode;
      });
    }
  }

  Future<void> _updateScoreMode(String mode) async {
    final normalized = mode.trim().isEmpty ? _manualScoreMode : mode.trim();
    final previous = _scoreMode;
    if (mounted) {
      setState(() {
        _scoreMode = normalized;
      });
    }

    try {
      final api = ref.read(apiClientProvider);
      await api.patch<Map<String, dynamic>>(
        '/users/me/settings',
        data: {'key': _scoreModeSettingKey, 'value': normalized},
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _scoreMode = previous;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de sauvegarder le mode de saisie.'),
          ),
        );
      }
    }
  }

  void _scheduleScoreAnimationCleanup(int playerIndex) {
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _animatedPlayerIndexes.remove(playerIndex);
      });
    });
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
    final remainingAfterThrow = currentPlayer.score - score;
    final shouldAnimateScore =
        remainingAfterThrow >= 0 && score > 0 && score <= currentPlayer.score;
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
      if (shouldAnimateScore) {
        setState(() {
          _animatedPlayerIndexes.add(currentPlayerIndex);
        });
        _scheduleScoreAnimationCleanup(currentPlayerIndex);
      }
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
      if (shouldAnimateScore) {
        setState(() {
          _animatedPlayerIndexes.add(currentPlayerIndex);
        });
        _scheduleScoreAnimationCleanup(currentPlayerIndex);
      }
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

  Future<void> _showSpectateQr() async {
    final match = ref.read(matchControllerProvider);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'QR spectateur',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: match.id));
                      if (!mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ID de la partie copie.')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    tooltip: 'Copier ID',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              QrImageView(
                data: match.id,
                version: QrVersions.auto,
                size: 220,
                eyeStyle: const QrEyeStyle(color: AppColors.textPrimary),
                dataModuleStyle: const QrDataModuleStyle(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Faites scanner ce QR code pour spectater la partie.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMatchSettings() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (ctx) {
        var localMode = _scoreMode;
        return StatefulBuilder(
          builder: (ctx, setModalState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Parametres partie',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: localMode,
                    decoration: const InputDecoration(
                      labelText: 'Mode de saisie',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _manualScoreMode,
                        child: Text('MANUAL'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setModalState(() {
                        localMode = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.qr_code_2,
                      color: AppColors.primary,
                    ),
                    title: const Text('QR spectateur'),
                    onTap: () => Navigator.pop(ctx, 'spectate'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.undo,
                      color: AppColors.textSecondary,
                    ),
                    title: const Text('Retour arriere'),
                    onTap: () => Navigator.pop(ctx, 'undo'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.flag_outlined,
                      color: AppColors.warning,
                    ),
                    title: const Text('Abandonner'),
                    onTap: () => Navigator.pop(ctx, 'abandon'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, 'save:$localMode'),
                      child: const Text('Appliquer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    if (selected.startsWith('save:')) {
      final mode = selected.substring(5);
      await _updateScoreMode(mode);
      return;
    }
    if (selected == 'spectate') {
      await _showSpectateQr();
      return;
    }
    if (selected == 'undo') {
      await _confirmUndo();
      return;
    }
    if (selected == 'abandon') {
      await _confirmAbandon();
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

    await _refreshPostMatchState();

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

  Future<void> _refreshPostMatchState() async {
    try {
      await ref.read(ongoingMatchesControllerProvider.notifier).refresh();
    } catch (_) {}

    try {
      await ref.read(profileControllerProvider.notifier).refresh();
    } catch (_) {}

    try {
      await ref.read(authControllerProvider.notifier).refreshCurrentUser();
    } catch (_) {}

    ref.invalidate(recentRankedMatchesProvider);
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
          '${match.mode} / ${match.setsToWin} Sets / ${match.legsPerSet} Legs',
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
            onPressed: _openMatchSettings,
            icon: const Icon(Icons.settings, color: AppColors.textSecondary),
            tooltip: 'Parametres partie',
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
              animatedPlayerIndexes: _animatedPlayerIndexes,
            ),

            if (_isX01Mode(match.mode))
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textSecondary,
                        indicatorColor: AppColors.primary,
                        tabs: [
                          Tab(text: 'Saisie score'),
                          Tab(text: 'Guideline'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            if (_scoreMode == _manualScoreMode)
                              SizedBox.expand(
                                child: DartInput(
                                  maxScore: match
                                      .players[match.currentPlayerIndex]
                                      .score,
                                  onSubmit: _submitScore,
                                  fillAvailableHeight: true,
                                ),
                              )
                            else
                              const Center(
                                child: Text(
                                  'Mode de saisie non supporte pour le moment.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            _X01GuidelineTab(
                              match: match,
                              currentPlayerIndex: match.currentPlayerIndex,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
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

class _X01GuidelineTab extends StatefulWidget {
  const _X01GuidelineTab({
    required this.match,
    required this.currentPlayerIndex,
  });

  final MatchModel match;
  final int currentPlayerIndex;

  @override
  State<_X01GuidelineTab> createState() => _X01GuidelineTabState();
}

class _X01GuidelineTabState extends State<_X01GuidelineTab> {
  bool _showRoundHistory = true;

  bool get _isDoubleOut {
    final normalized = widget.match.finishType.toLowerCase();
    return normalized == 'doubleout' || normalized == 'double_out';
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.match.players[widget.currentPlayerIndex];
    final score = player.score;
    final checkout = (score >= 2 && score <= 170) ? checkoutChart[score] : null;

    String hint;
    if (score == 0) {
      hint = 'Leg termine.';
    } else if (score > 170) {
      hint = 'Pas de finish direct, posez-vous pour un checkout.';
    } else if (_isDoubleOut && score == 1) {
      hint = 'Impossible en double-out a 1 restant.';
    } else if (checkout != null) {
      hint = 'Checkout recommande: $checkout';
    } else {
      hint = 'Aucune combinaison standard disponible.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Guideline ${widget.match.mode}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Joueur: ${player.name}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Score restant: $score',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Text(
                hint,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (widget.match.roundHistory.isNotEmpty) ...[
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() {
                    _showRoundHistory = !_showRoundHistory;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showRoundHistory
                            ? 'Masquer historique'
                            : 'Afficher historique',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _showRoundHistory
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: _showRoundHistory ? 96 : 0,
                child: ClipRect(
                  child: IgnorePointer(
                    ignoring: !_showRoundHistory,
                    child: RoundDetails(
                      roundHistory: widget.match.roundHistory,
                      players: widget.match.players,
                    ),
                  ),
                ),
              ),
            ],
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
