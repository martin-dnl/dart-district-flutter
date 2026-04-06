import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/network/api_providers.dart';
import '../controller/chasseur_match_controller.dart';
import '../controller/match_controller.dart';
import '../controller/ongoing_matches_controller.dart';
import '../data/match_service.dart';
import '../models/chasseur_match_state.dart';
import '../models/match_model.dart';
import '../widgets/dartboard_input.dart';
import '../widgets/tempo_zone_input.dart';

class ChasseurMatchScreen extends ConsumerStatefulWidget {
  const ChasseurMatchScreen({super.key});

  @override
  ConsumerState<ChasseurMatchScreen> createState() => _ChasseurMatchScreenState();
}

class _ChasseurMatchScreenState extends ConsumerState<ChasseurMatchScreen> {
  bool _endDialogShown = false;
  bool _completionSynced = false;
  String? _lastRemoteSyncKey;
  static const String _tempoMode = 'TEMPO';
  static const String _dartboardMode = 'DARTBOARD';
  String _scoreMode = _tempoMode;

  @override
  Widget build(BuildContext context) {
    ref.listen<ChasseurMatchState>(chasseurMatchControllerProvider, (prev, next) {
      if (next.status == MatchStatus.finished) {
        unawaited(_submitRemoteCompletionIfNeeded(next));
      }
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

    ref.listen<OngoingMatchesState>(ongoingMatchesControllerProvider, (_, next) {
      final current = ref.read(matchControllerProvider);
      if (!_isRemoteChasseur(current)) {
        return;
      }
      for (final candidate in next.matches) {
        if (candidate.id == current.id) {
          ref.read(matchControllerProvider.notifier).loadMatch(candidate);
          ref.read(chasseurMatchControllerProvider.notifier).loadRemoteMatch(candidate);
          break;
        }
      }
    });

    final state = ref.watch(chasseurMatchControllerProvider);
    final controller = ref.read(chasseurMatchControllerProvider.notifier);
    final remoteMatch = ref.watch(matchControllerProvider);

    if (_isRemoteChasseur(remoteMatch)) {
      final syncKey =
          '${remoteMatch.id}:${remoteMatch.roundHistory.length}:${remoteMatch.currentRound}:${remoteMatch.currentPlayerIndex}:${remoteMatch.status.name}';
      if (_lastRemoteSyncKey != syncKey) {
        _lastRemoteSyncKey = syncKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ref.read(chasseurMatchControllerProvider.notifier).loadRemoteMatch(remoteMatch);
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chasseur'),
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Parametres',
          ),
          IconButton(
            onPressed: () => context.go(AppRoutes.play),
            icon: const Icon(Icons.close),
            tooltip: 'Quitter',
          ),
        ],
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
                            child: _scoreMode == _dartboardMode
                                ? DartboardInput(
                                    maxScore: 180,
                                    fillAvailableHeight: true,
                                    submitEachDartInstantly: true,
                                    ringColorResolver: (sector, ring) {
                                      if (_isChasseurTargetSector(state, sector)) {
                                        return AppColors.warning.withValues(alpha: 0.70);
                                      }
                                      return null;
                                    },
                                    outerBullColor: _isChasseurTargetBull(state)
                                        ? AppColors.warning.withValues(alpha: 0.70)
                                        : null,
                                    innerBullColor: _isChasseurTargetBull(state)
                                        ? AppColors.warning.withValues(alpha: 0.82)
                                        : null,
                                    onSubmitVisit: (visit) {
                                      final hit = visit.dartHits.isNotEmpty ? visit.dartHits.first : null;
                                      if (hit == null || hit.score == 0) {
                                        final remote = ref.read(matchControllerProvider);
                                        if (_isRemoteChasseur(remote)) {
                                          _submitRemoteSingleChasseurDart(remote, -1, 1);
                                        } else {
                                          controller.registerDart(-1, 1);
                                        }
                                        return;
                                      }

                                      final parsed = _toChasseurDart(hit);
                                      if (parsed == null) {
                                        controller.registerDart(-1, 1);
                                        return;
                                      }

                                      final remote = ref.read(matchControllerProvider);
                                      if (_isRemoteChasseur(remote)) {
                                        _submitRemoteSingleChasseurDart(
                                          remote,
                                          parsed.zone,
                                          parsed.multiplier,
                                        );
                                      } else {
                                        controller.registerDart(parsed.zone, parsed.multiplier);
                                      }
                                    },
                                  )
                                : Column(
                                    children: [
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: TempoScoreInput(
                                          maxScore: 180,
                                          fillAvailableHeight: true,
                                          submitEachDartInstantly: true,
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
                                            final remote = ref.read(matchControllerProvider);
                                            if (_isRemoteChasseur(remote)) {
                                              _submitRemoteChasseurVisit(remote, visit);
                                              return;
                                            }
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

  bool _isChasseurTargetSector(ChasseurMatchState state, int sector) {
    final current = state.players[state.currentPlayerIndex];
    if (current.isHunter) {
      return state.players.asMap().entries.any(
        (entry) =>
            entry.key != state.currentPlayerIndex &&
            !entry.value.isEliminated &&
            entry.value.zone == sector,
      );
    }
    return current.zone == sector;
  }

  bool _isChasseurTargetBull(ChasseurMatchState state) {
    return _isChasseurTargetSector(state, 25);
  }

  ({int zone, int multiplier})? _toChasseurDart(DartHit hit) {
    final ring = hit.ring;
    final sector = hit.sectorNumber;

    if (ring == DartRing.innerBull) {
      return (zone: 25, multiplier: 2);
    }
    if (ring == DartRing.outerBull) {
      return (zone: 25, multiplier: 1);
    }
    if (sector == null) {
      return null;
    }

    final multiplier = switch (ring) {
      DartRing.double => 2,
      DartRing.triple => 3,
      _ => 1,
    };
    return (zone: sector, multiplier: multiplier);
  }

  bool _isRemoteChasseur(MatchModel match) {
    final hasRemoteContext = match.inviterId != null || match.inviteeId != null;
    return hasRemoteContext && match.mode.toLowerCase() == 'chasseur';
  }

  Future<void> _submitRemoteChasseurVisit(MatchModel match, TempoVisit visit) async {
    final api = ref.read(apiClientProvider);
    final service = MatchService(api);
    final throwerIndex = ref.read(chasseurMatchControllerProvider).currentPlayerIndex;

    try {
      MatchModel current = match;
      for (final shot in visit.darts) {
        final zone = shot.isMiss || shot.score == 0
            ? -1
            : (shot.zone == 50 ? 25 : shot.zone);
        final multiplier = shot.isMiss || shot.score == 0 ? 1 : shot.multiplier;
        final score = zone <= 0 ? 0 : zone * multiplier;

        current = await service.updateMatchScore(
          matchId: current.id,
          playerIndex: throwerIndex,
          score: score,
          dartPositions: <Map<String, dynamic>>[
            {
              'x': 0.0,
              'y': 0.0,
              'score': score,
              'label': 'H:$zone:$multiplier',
            },
          ],
        );
      }

      if (!mounted) {
        return;
      }
      ref.read(matchControllerProvider.notifier).loadMatch(current);
      ref.read(chasseurMatchControllerProvider.notifier).loadRemoteMatch(current);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Synchronisation Chasseur indisponible.')),
      );
    }
  }

  Future<void> _submitRemoteSingleChasseurDart(
    MatchModel match,
    int zone,
    int multiplier,
  ) async {
    final api = ref.read(apiClientProvider);
    final service = MatchService(api);
    final throwerIndex = ref.read(chasseurMatchControllerProvider).currentPlayerIndex;
    final score = zone <= 0 ? 0 : zone * multiplier;
    try {
      final updated = await service.updateMatchScore(
        matchId: match.id,
        playerIndex: throwerIndex,
        score: score,
        dartPositions: <Map<String, dynamic>>[
          {
            'x': 0.0,
            'y': 0.0,
            'score': score,
            'label': 'H:$zone:$multiplier',
          },
        ],
      );
      if (!mounted) {
        return;
      }
      ref.read(matchControllerProvider.notifier).loadMatch(updated);
      ref.read(chasseurMatchControllerProvider.notifier).loadRemoteMatch(updated);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Synchronisation Chasseur indisponible.')),
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
                      DropdownMenuItem(value: _tempoMode, child: Text('TEMPO')),
                      DropdownMenuItem(value: _dartboardMode, child: Text('DARTBOARD')),
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
                    leading: const Icon(Icons.undo, color: AppColors.textSecondary),
                    title: const Text('Retour arriere du round'),
                    onTap: () => Navigator.pop(ctx, 'undo_round'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flag_outlined, color: AppColors.warning),
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
      setState(() {
        _scoreMode = selected.substring(5);
      });
      return;
    }
    if (selected == 'undo_round') {
      final remote = ref.read(matchControllerProvider);
      if (_isRemoteChasseur(remote)) {
        await _undoRemoteRound(remote);
      } else {
        ref.read(chasseurMatchControllerProvider.notifier).undoRound();
      }
      return;
    }
    if (selected == 'abandon') {
      await _abandonCurrentPlayer();
    }
  }

  Future<void> _undoRemoteRound(MatchModel match) async {
    final api = ref.read(apiClientProvider);
    final service = MatchService(api);
    MatchModel current = match;
    try {
      for (var i = 0; i < 3; i++) {
        current = await service.undoLastThrow(current.id);
      }
      if (!mounted) {
        return;
      }
      ref.read(matchControllerProvider.notifier).loadMatch(current);
      ref.read(chasseurMatchControllerProvider.notifier).loadRemoteMatch(current);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de revenir au round precedent.')),
      );
    }
  }

  Future<void> _abandonCurrentPlayer() async {
    final remote = ref.read(matchControllerProvider);
    final localState = ref.read(chasseurMatchControllerProvider);
    final playerIndex = localState.currentPlayerIndex;

    if (_isRemoteChasseur(remote)) {
      final api = ref.read(apiClientProvider);
      final service = MatchService(api);
      try {
        final updated = await service.abandonMatch(
          matchId: remote.id,
          surrenderedByIndex: playerIndex,
        );
        if (!mounted) {
          return;
        }
        ref.read(matchControllerProvider.notifier).loadMatch(updated);
        ref.read(chasseurMatchControllerProvider.notifier).loadRemoteMatch(updated);
        await ref.read(ongoingMatchesControllerProvider.notifier).refresh();
      } catch (_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'abandonner la partie.')),
        );
      }
      return;
    }

    ref.read(chasseurMatchControllerProvider.notifier).abandonMatch(playerIndex);
  }

  Future<void> _submitRemoteCompletionIfNeeded(ChasseurMatchState state) async {
    if (_completionSynced) {
      return;
    }

    final remote = ref.read(matchControllerProvider);
    if (!_isRemoteChasseur(remote)) {
      return;
    }
    if (remote.status == MatchStatus.finished) {
      _completionSynced = true;
      return;
    }

    final winnerIndex = state.winnerIndex;
    if (winnerIndex == null || winnerIndex < 0 || winnerIndex >= state.players.length) {
      return;
    }

    final surrenderedIndex = List<int>.generate(state.players.length, (i) => i)
        .firstWhere((i) => i != winnerIndex, orElse: () => -1);
    if (surrenderedIndex < 0) {
      return;
    }

    final api = ref.read(apiClientProvider);
    final service = MatchService(api);
    try {
      final updated = await service.abandonMatch(
        matchId: remote.id,
        surrenderedByIndex: surrenderedIndex,
      );
      if (!mounted) {
        return;
      }
      _completionSynced = true;
      ref.read(matchControllerProvider.notifier).loadMatch(updated);
      ref.read(chasseurMatchControllerProvider.notifier).loadRemoteMatch(updated);
      await ref.read(ongoingMatchesControllerProvider.notifier).refresh();
    } catch (_) {
      // Keep unsynced to retry on next state update.
    }
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
