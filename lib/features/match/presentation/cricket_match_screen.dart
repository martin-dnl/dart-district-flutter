import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/config/translation_service.dart';
import '../../../core/network/api_providers.dart';
import '../../../shared/widgets/neon_modal.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/cricket_match_controller.dart';
import '../controller/match_controller.dart';
import '../controller/ongoing_matches_controller.dart';
import '../data/match_service.dart';
import '../models/cricket_match_state.dart';
import '../models/match_model.dart';
import '../widgets/dartboard_input.dart';

class CricketMatchScreen extends ConsumerStatefulWidget {
  const CricketMatchScreen({super.key});

  @override
  ConsumerState<CricketMatchScreen> createState() => _CricketMatchScreenState();
}

class _CricketMatchScreenState extends ConsumerState<CricketMatchScreen> {
  bool _endDialogShown = false;
  bool _completionSynced = false;
  Timer? _pendingShotTimer;
  int? _pendingZone;
  int _pendingMultiplier = 0;
  String? _lastRemoteSyncKey;
  static const String _manualMode = 'MANUAL';
  static const String _dartboardMode = 'DARTBOARD';
  String _scoreMode = _manualMode;

  @override
  void dispose() {
    _pendingShotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CricketMatchState>(cricketMatchControllerProvider, (prev, next) {
      if (next.status == MatchStatus.finished) {
        unawaited(_syncRemoteCompletionIfNeeded(next));
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

    ref.listen<OngoingMatchesState>(ongoingMatchesControllerProvider, (
      _,
      next,
    ) {
      final current = ref.read(matchControllerProvider);
      if (!_isRemoteCricket(current)) {
        return;
      }
      for (final candidate in next.matches) {
        if (candidate.id == current.id) {
          ref.read(matchControllerProvider.notifier).loadMatch(candidate);
          ref
              .read(cricketMatchControllerProvider.notifier)
              .loadRemoteMatch(candidate);
          break;
        }
      }
    });

    final state = ref.watch(cricketMatchControllerProvider);
    final remoteMatch = ref.watch(matchControllerProvider);

    if (_isRemoteCricket(remoteMatch)) {
      final syncKey =
          '${remoteMatch.id}:${remoteMatch.roundHistory.length}:${remoteMatch.currentRound}:${remoteMatch.currentPlayerIndex}:${remoteMatch.status.name}';
      if (_lastRemoteSyncKey != syncKey) {
        _lastRemoteSyncKey = syncKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ref
              .read(cricketMatchControllerProvider.notifier)
              .loadRemoteMatch(remoteMatch);
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t('SCREEN.CRICKET.TITLE', fallback: 'Cricket')),
        leading: IconButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.play);
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
            tooltip: t('SCREEN.CRICKET.SETTINGS', fallback: 'Parametres'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _CricketScoreboard(state: state),
            _TurnIndicator(state: state),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _scoreMode == _dartboardMode
                    ? DartboardInput(
                        maxScore: 180,
                        fillAvailableHeight: true,
                        submitEachDartInstantly: true,
                        ringColorResolver: (sector, ring) {
                          final currentPlayer =
                              state.players[state.currentPlayerIndex];
                          if (cricketZones.contains(sector)) {
                            if ((currentPlayer.hits[sector] ?? 0) >= 3) {
                              return AppColors.primary.withValues(alpha: 0.78);
                            }
                            return AppColors.warning.withValues(alpha: 0.72);
                          }
                          return null;
                        },
                        ringLabelResolver: (sector, ring) {
                          if (ring != DartRing.singleOuter) {
                            return null;
                          }
                          if (!cricketZones.contains(sector)) {
                            return null;
                          }
                          final currentPlayer =
                              state.players[state.currentPlayerIndex];
                          final remaining =
                              (3 - (currentPlayer.hits[sector] ?? 0)).clamp(
                                0,
                                3,
                              );
                          return remaining > 0 ? '$remaining' : '';
                        },
                        outerBullColor:
                            (state.players[state.currentPlayerIndex].hits[25] ??
                                    0) >=
                                3
                            ? AppColors.primary.withValues(alpha: 0.78)
                            : AppColors.warning.withValues(alpha: 0.72),
                        innerBullColor:
                            (state.players[state.currentPlayerIndex].hits[25] ??
                                    0) >=
                                3
                            ? AppColors.primary.withValues(alpha: 0.86)
                            : AppColors.warning.withValues(alpha: 0.82),
                        onSubmitVisit: (visit) {
                          final hit = visit.dartHits.isNotEmpty
                              ? visit.dartHits.first
                              : null;
                          if (hit == null || hit.score == 0) {
                            final remote = ref.read(matchControllerProvider);
                            if (_isRemoteCricket(remote)) {
                              unawaited(
                                _submitRemoteCricketDart(remote, -1, 1),
                              );
                            } else {
                              ref
                                  .read(cricketMatchControllerProvider.notifier)
                                  .registerDart(-1, 1);
                            }
                            return;
                          }

                          final parsed = _toCricketDart(hit);
                          if (parsed == null) {
                            ref
                                .read(cricketMatchControllerProvider.notifier)
                                .registerDart(-1, 1);
                            return;
                          }

                          final remote = ref.read(matchControllerProvider);
                          if (_isRemoteCricket(remote)) {
                            unawaited(
                              _submitRemoteCricketDart(
                                remote,
                                parsed.zone,
                                parsed.multiplier,
                              ),
                            );
                          } else {
                            ref
                                .read(cricketMatchControllerProvider.notifier)
                                .registerDart(parsed.zone, parsed.multiplier);
                          }
                        },
                      )
                    : _CricketGrid(state: state, onTapZone: _onTapZone),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTapZone(int zone) {
    final state = ref.read(cricketMatchControllerProvider);
    if (state.status != MatchStatus.inProgress) {
      return;
    }

    if (_pendingZone == zone) {
      _pendingMultiplier = (_pendingMultiplier + 1).clamp(
        1,
        zone == 25 ? 2 : 3,
      );
    } else {
      _commitPendingShot();
      _pendingZone = zone;
      _pendingMultiplier = 1;
    }

    _pendingShotTimer?.cancel();
    _pendingShotTimer = Timer(
      const Duration(milliseconds: 520),
      _commitPendingShot,
    );
  }

  void _commitPendingShot() {
    final zone = _pendingZone;
    final multiplier = _pendingMultiplier;
    if (zone == null || multiplier < 1) {
      return;
    }

    _pendingShotTimer?.cancel();
    _pendingShotTimer = null;
    _pendingZone = null;
    _pendingMultiplier = 0;
    final current = ref.read(matchControllerProvider);
    if (_isRemoteCricket(current)) {
      unawaited(_submitRemoteCricketDart(current, zone, multiplier));
      return;
    }

    ref
        .read(cricketMatchControllerProvider.notifier)
        .registerDart(zone, multiplier);
  }

  bool _isRemoteCricket(MatchModel match) {
    final hasRemoteContext = match.inviterId != null || match.inviteeId != null;
    return hasRemoteContext && match.mode.toLowerCase() == 'cricket';
  }

  ({int zone, int multiplier})? _toCricketDart(DartHit hit) {
    if (hit.ring == DartRing.innerBull) {
      return (zone: 25, multiplier: 2);
    }
    if (hit.ring == DartRing.outerBull) {
      return (zone: 25, multiplier: 1);
    }
    if (hit.sectorNumber == null) {
      return null;
    }
    final multiplier = switch (hit.ring) {
      DartRing.double => 2,
      DartRing.triple => 3,
      _ => 1,
    };
    return (zone: hit.sectorNumber!, multiplier: multiplier);
  }

  Future<void> _submitRemoteCricketDart(
    MatchModel match,
    int zone,
    int multiplier,
  ) async {
    final api = ref.read(apiClientProvider);
    final service = MatchService(api);
    final score = zone <= 0 ? 0 : zone * multiplier;

    try {
      final updated = await service.updateMatchScore(
        matchId: match.id,
        playerIndex: match.currentPlayerIndex,
        score: score,
        dartPositions: <Map<String, dynamic>>[
          {'x': 0.0, 'y': 0.0, 'score': score, 'label': 'C:$zone:$multiplier'},
        ],
      );
      if (!mounted) {
        return;
      }
      ref.read(matchControllerProvider.notifier).loadMatch(updated);
      ref
          .read(cricketMatchControllerProvider.notifier)
          .loadRemoteMatch(updated);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'SCREEN.CRICKET.SYNC_UNAVAILABLE',
              fallback: 'Synchronisation Cricket indisponible.',
            ),
          ),
        ),
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
                  Text(
                    t(
                      'SCREEN.CRICKET.MATCH_SETTINGS',
                      fallback: 'Parametres partie',
                    ),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: localMode,
                    decoration: InputDecoration(
                      labelText: t(
                        'SCREEN.CRICKET.INPUT_MODE',
                        fallback: 'Mode de saisie',
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _manualMode,
                        child: Text('MANUAL'),
                      ),
                      DropdownMenuItem(
                        value: _dartboardMode,
                        child: Text('DARTBOARD'),
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
                      Icons.undo,
                      color: AppColors.textSecondary,
                    ),
                    title: Text(
                      t(
                        'SCREEN.CRICKET.UNDO_ROUND',
                        fallback: 'Retour arriere du round',
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, 'undo_round'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.flag_outlined,
                      color: AppColors.warning,
                    ),
                    title: Text(
                      t('SCREEN.CRICKET.SURRENDER', fallback: 'Abandonner'),
                    ),
                    onTap: () => Navigator.pop(ctx, 'abandon'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, 'save:$localMode'),
                      child: Text(t('COMMON.APPLY', fallback: 'Appliquer')),
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
      if (_isRemoteCricket(remote)) {
        await _undoRemoteRound(remote);
      } else {
        ref.read(cricketMatchControllerProvider.notifier).undoRound();
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
      ref
          .read(cricketMatchControllerProvider.notifier)
          .loadRemoteMatch(current);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'SCREEN.CRICKET.UNDO_ROUND_FAILED',
              fallback: 'Impossible de revenir au round precedent.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _abandonCurrentPlayer() async {
    final remote = ref.read(matchControllerProvider);
    final localState = ref.read(cricketMatchControllerProvider);
    final currentUser = ref.read(currentUserProvider);
    var playerIndex = localState.currentPlayerIndex;

    if (_isRemoteCricket(remote)) {
      final username = currentUser?.username ?? '';
      final foundIndex = remote.players.indexWhere((p) => p.name == username);
      if (foundIndex >= 0) {
        playerIndex = foundIndex;
      }

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
        ref
            .read(cricketMatchControllerProvider.notifier)
            .loadRemoteMatch(updated);
        await ref.read(ongoingMatchesControllerProvider.notifier).refresh();
      } catch (_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'SCREEN.CRICKET.SURRENDER_FAILED',
                fallback: 'Impossible d\'abandonner la partie.',
              ),
            ),
          ),
        );
      }
      return;
    }

    ref.read(cricketMatchControllerProvider.notifier).abandonMatch(playerIndex);
  }

  Future<void> _syncRemoteCompletionIfNeeded(CricketMatchState state) async {
    if (_completionSynced) {
      return;
    }

    final remote = ref.read(matchControllerProvider);
    if (!_isRemoteCricket(remote)) {
      return;
    }
    if (remote.status == MatchStatus.finished) {
      _completionSynced = true;
      return;
    }

    final winnerIndex = state.winnerIndex;
    if (winnerIndex == null ||
        winnerIndex < 0 ||
        winnerIndex >= state.players.length) {
      return;
    }

    final loserIndex = List<int>.generate(
      state.players.length,
      (i) => i,
    ).firstWhere((i) => i != winnerIndex, orElse: () => -1);
    if (loserIndex < 0) {
      return;
    }

    final api = ref.read(apiClientProvider);
    final service = MatchService(api);
    try {
      final updated = await service.abandonMatch(
        matchId: remote.id,
        surrenderedByIndex: loserIndex,
      );
      if (!mounted) {
        return;
      }
      _completionSynced = true;
      ref.read(matchControllerProvider.notifier).loadMatch(updated);
      ref
          .read(cricketMatchControllerProvider.notifier)
          .loadRemoteMatch(updated);
      await ref.read(ongoingMatchesControllerProvider.notifier).refresh();
    } catch (_) {
      // Keep unsynced to retry on next state update.
    }
  }

  Future<void> _showEndDialog(CricketMatchState state) async {
    final winner = state.winnerIndex != null
        ? state.players[state.winnerIndex!]
        : null;
    final recent = state.roundHistory.reversed.take(4).toList(growable: false);

    await showNeonDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            t('SCREEN.CRICKET.MATCH_FINISHED', fallback: 'Match termine'),
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  winner == null
                      ? t(
                          'SCREEN.CRICKET.END_MESSAGE',
                          fallback: 'Fin de partie.',
                        )
                      : '${winner.name} ${t('SCREEN.CRICKET.WINS_MESSAGE', fallback: 'remporte la partie de Cricket.')}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < state.players.length; i++) ...[
                  Text(
                    '${state.players[i].name}: ${cricketZones.where((z) => state.players[i].isClosed(z)).length}/7 zones fermees - ${state.players[i].score} pts',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                  if (i < state.players.length - 1) const SizedBox(height: 4),
                ],
                if (recent.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    t('SCREEN.CRICKET.LAST_ROUNDS', fallback: 'Derniers tours'),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final round in recent)
                    Text(
                      'R${round.round} · ${state.players[round.playerIndex].name}: ${round.darts.map((d) => d.multiplier == 1 ? 'S${d.zone == 25 ? 'B' : d.zone}' : (d.multiplier == 2 ? 'D${d.zone == 25 ? 'B' : d.zone}' : 'T${d.zone == 25 ? 'B' : d.zone}')).join(' - ')}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t('COMMON.CLOSE', fallback: 'Fermer')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go(AppRoutes.play);
              },
              child: Text(
                t('SCREEN.CRICKET.BACK_TO_MENU', fallback: 'Revenir au menu'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CricketScoreboard extends StatelessWidget {
  const _CricketScoreboard({required this.state});

  final CricketMatchState state;

  @override
  Widget build(BuildContext context) {
    final playerCount = state.players.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          for (var i = 0; i < playerCount; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _PlayerPanel(
                player: state.players[i],
                isActive:
                    state.currentPlayerIndex == i &&
                    state.status == MatchStatus.inProgress,
                compact: playerCount > 2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({
    required this.player,
    required this.isActive,
    this.compact = false,
  });

  final CricketPlayerState player;
  final bool isActive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 6 : 10),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.14)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.surfaceLight,
          width: isActive ? 1.4 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 12 : 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${player.score}',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: compact ? 20 : 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'L${player.legsWon} S${player.setsWon}',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: compact ? 10 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CricketGrid extends StatelessWidget {
  const _CricketGrid({required this.state, required this.onTapZone});

  final CricketMatchState state;
  final ValueChanged<int> onTapZone;

  @override
  Widget build(BuildContext context) {
    final playerCount = state.players.length;
    // Build column headers: player names on either side of center zone column
    // Layout: [P1] [Zone] [P2] [P3?] [P4?]
    // With 2 players: P1 | Zone | P2
    // With 3 players: P1 | Zone | P2 | P3
    // With 4 players: P1 | Zone | P2 | P3 | P4

    return Column(
      children: [
        // Header row with player names
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              // Player 1 column header
              Expanded(
                child: Center(
                  child: Text(
                    state.players[0].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: state.currentPlayerIndex == 0
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              // Zone column header
              const SizedBox(
                width: 52,
                child: Center(
                  child: Text(
                    'Zone',
                    style: TextStyle(
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              // Remaining player column headers (P2, P3, P4)
              for (var p = 1; p < playerCount; p++)
                Expanded(
                  child: Center(
                    child: Text(
                      state.players[p].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: state.currentPlayerIndex == p
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Grid rows
        Expanded(
          child: ListView.separated(
            itemCount: cricketZones.length,
            separatorBuilder: (_, _2) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final zone = cricketZones[index];
              final closedByAll = state.players.every((p) => p.isClosed(zone));

              return Row(
                children: [
                  // Player 1 cell
                  Expanded(
                    child: _CricketCell(
                      hits: state.players[0].hits[zone] ?? 0,
                      active:
                          state.currentPlayerIndex == 0 &&
                          state.status == MatchStatus.inProgress,
                      scoringOpen:
                          state.players[0].isClosed(zone) &&
                          state.players
                              .asMap()
                              .entries
                              .where((e) => e.key != 0)
                              .any((e) => !e.value.isClosed(zone)),
                      fullyClosed: closedByAll,
                      onTap: () => onTapZone(zone),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Zone label (center)
                  SizedBox(
                    width: 52,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          zone == 25 ? 'BULL' : '$zone',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Remaining player cells (P2, P3, P4)
                  for (var p = 1; p < playerCount; p++) ...[
                    Expanded(
                      child: _CricketCell(
                        hits: state.players[p].hits[zone] ?? 0,
                        active:
                            state.currentPlayerIndex == p &&
                            state.status == MatchStatus.inProgress,
                        scoringOpen:
                            state.players[p].isClosed(zone) &&
                            state.players
                                .asMap()
                                .entries
                                .where((e) => e.key != p)
                                .any((e) => !e.value.isClosed(zone)),
                        fullyClosed: closedByAll,
                        onTap: () => onTapZone(zone),
                      ),
                    ),
                    if (p < playerCount - 1) const SizedBox(width: 4),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TurnIndicator extends StatelessWidget {
  const _TurnIndicator({required this.state});

  final CricketMatchState state;

  @override
  Widget build(BuildContext context) {
    final dartIndex = (state.currentDartInTurn + 1).clamp(1, 3);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tour ${state.currentRound}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
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

class _CricketCell extends StatelessWidget {
  const _CricketCell({
    required this.hits,
    required this.active,
    required this.scoringOpen,
    required this.fullyClosed,
    required this.onTap,
  });

  final int hits;
  final bool active;
  final bool scoringOpen;
  final bool fullyClosed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cellColor = fullyClosed
        ? AppColors.surface
        : scoringOpen
        ? AppColors.primary.withValues(alpha: 0.12)
        : (active ? AppColors.card : AppColors.surface);

    final paintColor = fullyClosed ? AppColors.textHint : AppColors.textPrimary;

    return GestureDetector(
      onTap: active ? onTap : null,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AppColors.primary.withValues(alpha: 0.6)
                : AppColors.surfaceLight,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 34,
            height: 34,
            child: CustomPaint(
              painter: _CricketHitsPainter(hits: hits, color: paintColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _CricketHitsPainter extends CustomPainter {
  const _CricketHitsPainter({required this.hits, required this.color});

  final int hits;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final markSize = size.shortestSide * 0.28;

    if (hits >= 1) {
      canvas.drawLine(
        Offset(cx - markSize, cy + markSize),
        Offset(cx + markSize, cy - markSize),
        paint,
      );
    }
    if (hits >= 2) {
      canvas.drawLine(
        Offset(cx - markSize, cy - markSize),
        Offset(cx + markSize, cy + markSize),
        paint,
      );
    }
    if (hits >= 3) {
      canvas.drawCircle(Offset(cx, cy), markSize * 1.35, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CricketHitsPainter oldDelegate) {
    return oldDelegate.hits != hits || oldDelegate.color != color;
  }
}
