import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/network/api_providers.dart';
import '../controller/chasseur_match_controller.dart';
import '../models/chasseur_match_state.dart';
import '../models/match_model.dart';
import '../widgets/tempo_zone_input.dart';

class ChasseurMatchScreen extends ConsumerStatefulWidget {
  const ChasseurMatchScreen({super.key});

  @override
  ConsumerState<ChasseurMatchScreen> createState() => _ChasseurMatchScreenState();
}

class _ChasseurMatchScreenState extends ConsumerState<ChasseurMatchScreen> {
  bool _endDialogShown = false;
  static const String _scoreModeSettingKey = 'GAME_OPTION.SCORE_MODE';
  static const String _manualScoreMode = 'MANUAL';
  static const String _dartboardScoreMode = 'DARTBOARD';
  static const String _tempoScoreMode = 'TEMPO';
  String _scoreMode = _manualScoreMode;

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
    setState(() {
      _scoreMode = normalized;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.patch<Map<String, dynamic>>(
        '/users/me/settings',
        data: {'key': _scoreModeSettingKey, 'value': normalized},
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scoreMode = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de sauvegarder le mode.')),
      );
    }
  }

  Future<void> _openSettings() async {
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
                      DropdownMenuItem(
                        value: _dartboardScoreMode,
                        child: Text('DARTBOARD'),
                      ),
                      DropdownMenuItem(
                        value: _tempoScoreMode,
                        child: Text('TEMPO'),
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
                  const SizedBox(height: 8),
                  const Text(
                    'Mode DARTBOARD non disponible pour Chasseur pour le moment.',
                    style: TextStyle(color: AppColors.textHint, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, localMode),
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

    if (selected != null) {
      await _updateScoreMode(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChasseurMatchState>(chasseurMatchControllerProvider, (prev, next) {
      if (!_endDialogShown && next.status == MatchStatus.finished && mounted) {
        _endDialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _showEndDialog(next);
        });
      }
    });

    final state = ref.watch(chasseurMatchControllerProvider);
    final controller = ref.read(chasseurMatchControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chasseur'),
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings, color: AppColors.textSecondary),
            tooltip: 'Parametres partie',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Header(state: state),
            const SizedBox(height: 8),
            SizedBox(
              height: 128,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final player = state.players[index];
                  return _PlayerCard(
                    player: player,
                    isActive: state.currentPlayerIndex == index && state.status == MatchStatus.inProgress,
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemCount: state.players.length,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: state.lastFeedback == null
                      ? const SizedBox.shrink()
                      : Container(
                          key: ValueKey<String>(state.lastFeedback!),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: Text(
                            state.lastFeedback!,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _scoreMode == _tempoScoreMode
                    ? TempoZoneInput(
                        remainingDarts: 3 - state.currentDartInTurn,
                        canSelectZone: (zone) {
                          final ownerIndex = state.players.indexWhere(
                            (p) => p.zone == zone && !p.isEliminated,
                          );
                          final current = state.players[state.currentPlayerIndex];
                          if (ownerIndex == -1) {
                            return true;
                          }
                          if (ownerIndex == state.currentPlayerIndex) {
                            return true;
                          }
                          return current.isHunter;
                        },
                        onSubmit: (shots) {
                          for (final shot in shots) {
                            if (shot.isMiss) {
                              controller.registerDart(-1, 1);
                              continue;
                            }
                            controller.registerDart(shot.zone, shot.multiplier);
                          }
                        },
                      )
                    : _ZoneGrid(
                        state: state,
                        onSingle: (zone) => controller.registerDart(zone, 1),
                        onDouble: (zone) => controller.registerDart(zone, 2),
                        onTriple: (zone) => controller.registerDart(zone, 3),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.undoLastDart,
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.go(AppRoutes.play),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Quitter'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEndDialog(ChasseurMatchState state) async {
    final winner = state.winnerIndex != null ? state.players[state.winnerIndex!] : null;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Manche terminee',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            winner == null
                ? 'Fin de partie.'
                : '${winner.name} est le dernier survivant.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go(AppRoutes.play);
              },
              child: const Text('Revenir au menu'),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final ChasseurMatchState state;

  @override
  Widget build(BuildContext context) {
    final dartIndex = (state.currentDartInTurn + 1).clamp(1, 3);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tour ${state.currentRound}',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
          Text(
            'Flechette $dartIndex/3',
            style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.player, required this.isActive});

  final ChasseurPlayerState player;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary.withValues(alpha: 0.14) : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.surfaceLight,
          width: isActive ? 1.3 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(4, (i) {
              if (player.isEliminated) {
                return const Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: Icon(Icons.close, size: 16, color: AppColors.error),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  i < player.lives ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: i < player.lives ? AppColors.error : AppColors.textHint,
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            'Zone ${player.zone == 25 ? 'Bull' : (player.zone?.toString() ?? '-')}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          if (player.isEliminated)
            const Text(
              'OUT',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
            )
          else if (player.isHunter)
            const Text(
              'CHASSEUR',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}

class _ZoneGrid extends StatelessWidget {
  const _ZoneGrid({
    required this.state,
    required this.onSingle,
    required this.onDouble,
    required this.onTriple,
  });

  final ChasseurMatchState state;
  final ValueChanged<int> onSingle;
  final ValueChanged<int> onDouble;
  final ValueChanged<int> onTriple;

  @override
  Widget build(BuildContext context) {
    final zones = [...List<int>.generate(20, (i) => i + 1), 25];
    final current = state.players[state.currentPlayerIndex];

    return GridView.builder(
      itemCount: zones.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) {
        final zone = zones[index];
        final ownerIndex = state.players.indexWhere((p) => p.zone == zone && !p.isEliminated);
        final owner = ownerIndex >= 0 ? state.players[ownerIndex] : null;

        final isOwnZone = current.zone == zone;
        final isTargetZone = current.isHunter && owner != null && ownerIndex != state.currentPlayerIndex;

        final color = isOwnZone
            ? AppColors.primary.withValues(alpha: 0.16)
            : isTargetZone
                ? AppColors.error.withValues(alpha: 0.14)
                : AppColors.card;

        final enabled = state.status == MatchStatus.inProgress && !current.isEliminated;

        return GestureDetector(
          onTap: enabled ? () => onSingle(zone) : null,
          onDoubleTap: enabled ? () => onDouble(zone) : null,
          onLongPress: enabled ? () => onTriple(zone) : null,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isOwnZone
                    ? AppColors.primary
                    : (isTargetZone ? AppColors.error : AppColors.surfaceLight),
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  zone == 25 ? 'Bull' : '$zone',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (owner != null)
                  Text(
                    owner.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
