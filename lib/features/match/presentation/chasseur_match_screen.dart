import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Header(state: state),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: List<Widget>.generate(state.players.length, (index) {
                  final player = state.players[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: index == state.players.length - 1 ? 0 : 8),
                    child: _PlayerCard(
                      player: player,
                      isActive: state.currentPlayerIndex == index &&
                          state.status == MatchStatus.inProgress,
                    ),
                  );
                }),
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              children: [
                                const SizedBox(height: 8),
                                const _LockedModeSelector(),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: TempoScoreInput(
                                    maxScore: 180,
                                    fillAvailableHeight: true,
                                    gridCrossAxisCount: 4,
                                    zones: const [
                                      1,
                                      2,
                                      3,
                                      4,
                                      5,
                                      6,
                                      7,
                                      8,
                                      9,
                                      10,
                                      11,
                                      12,
                                      13,
                                      14,
                                      15,
                                      16,
                                      17,
                                      18,
                                      19,
                                      20,
                                      25,
                                      50,
                                    ],
                                    canSelectZone: (zone) => _canSelectTempoZone(state, zone),
                                    onSubmitVisit: (visit) {
                                      for (final shot in visit.darts) {
                                        if (shot.isMiss || shot.score == 0) {
                                          controller.registerDart(-1, 1);
                                          continue;
                                        }
                                        final zone = shot.zone == 50 ? 25 : shot.zone;
                                        controller.registerDart(zone, shot.multiplier);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _ChasseurGuidelineTab(state: state),
                        ],
                      ),
                    ),
                  ],
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

  bool _canSelectTempoZone(ChasseurMatchState state, int zone) {
    final normalizedZone = zone == 50 ? 25 : zone;
    final ownerIndex = state.players.indexWhere(
      (p) => p.zone == normalizedZone && !p.isEliminated,
    );
    final current = state.players[state.currentPlayerIndex];

    if (ownerIndex == -1) {
      return true;
    }
    if (ownerIndex == state.currentPlayerIndex) {
      return true;
    }
    return current.isHunter;
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
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Flechette $dartIndex/3',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
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
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary.withValues(alpha: 0.14) : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.surfaceLight,
          width: isActive ? 1.3 : 0.8,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Zone ${player.zone == 25 ? 'Bull' : (player.zone?.toString() ?? '-')}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: List.generate(4, (i) {
              if (player.isEliminated) {
                return const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Icon(Icons.close, size: 16, color: AppColors.error),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(
                  i < player.lives ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: i < player.lives ? AppColors.error : AppColors.textHint,
                ),
              );
            }),
          ),
          const SizedBox(width: 8),
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

class _LockedModeSelector extends StatelessWidget {
  const _LockedModeSelector();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _ModePill(
            label: 'MANUAL',
            selected: false,
            enabled: false,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _ModePill(
            label: 'TEMPO',
            selected: true,
            enabled: true,
          ),
        ),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.selected,
    required this.enabled,
  });

  final String label;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.2)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.surfaceLight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        enabled ? label : '$label (disabled)',
        style: TextStyle(
          color: enabled
              ? (selected ? AppColors.primary : AppColors.textSecondary)
              : AppColors.textHint,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ChasseurGuidelineTab extends StatelessWidget {
  const _ChasseurGuidelineTab({required this.state});

  final ChasseurMatchState state;

  @override
  Widget build(BuildContext context) {
    final current = state.players[state.currentPlayerIndex];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Guideline Chasseur',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Text(
              current.isHunter
                  ? 'Mode chasseur actif: ciblez les zones adverses pour retirer des vies.'
                  : 'Defendez votre zone (${current.zone == 25 ? 'Bull' : (current.zone?.toString() ?? '-')}) pour monter a 4 vies.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: state.roundHistory.length,
              reverse: true,
              itemBuilder: (context, index) {
                final item = state.roundHistory[state.roundHistory.length - 1 - index];
                final player = state.players[item.playerIndex];
                final darts = item.darts
                    .map((d) {
                      final prefix = d.multiplier == 1 ? 'S' : d.multiplier == 2 ? 'D' : 'T';
                      final zoneText = d.zone == 25 ? 'Bull' : '${d.zone}';
                      return '$prefix$zoneText';
                    })
                    .join(' - ');

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'R${item.round}',
                        style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${player.name}: $darts',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
