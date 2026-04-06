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

class ChasseurZoneSelectionScreen extends ConsumerWidget {
  const ChasseurZoneSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<OngoingMatchesState>(ongoingMatchesControllerProvider, (_, next) {
      final remote = ref.read(matchControllerProvider);
      if (!_isRemoteChasseur(remote)) {
        return;
      }
      for (final candidate in next.matches) {
        if (candidate.id == remote.id) {
          ref.read(matchControllerProvider.notifier).loadMatch(candidate);
          ref.read(chasseurMatchControllerProvider.notifier).loadRemoteMatch(candidate);
          break;
        }
      }
    });

    ref.listen<ChasseurMatchState>(chasseurMatchControllerProvider, (prev, next) {
      if (prev?.phase != ChasseurPhase.playing &&
          next.phase == ChasseurPhase.playing &&
          context.mounted) {
        context.go(AppRoutes.matchChasseur);
      }
    });

    final state = ref.watch(chasseurMatchControllerProvider);
    final controller = ref.read(chasseurMatchControllerProvider.notifier);
    final remoteMatch = ref.watch(matchControllerProvider);
    final isRemote = _isRemoteChasseur(remoteMatch);

    if (isRemote) {
      final syncKey =
          '${remoteMatch.id}:${remoteMatch.roundHistory.length}:${remoteMatch.currentRound}:${remoteMatch.currentPlayerIndex}:${remoteMatch.status.name}';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        final currentState = ref.read(chasseurMatchControllerProvider);
        final currentSyncKey =
            '${remoteMatch.id}:${currentState.roundHistory.length}:${currentState.currentRound}:${currentState.currentPlayerIndex}:${currentState.status.name}';
        if (syncKey != currentSyncKey) {
          controller.loadRemoteMatch(remoteMatch);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Selection des zones'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'Chaque joueur doit choisir sa zone cible (1-20 ou Bull).',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...state.players.asMap().entries.map((entry) {
              final index = entry.key;
              final player = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PlayerZoneSelector(
                  playerName: player.name,
                  selectedZone: player.zone,
                  enabled: true,
                  isZoneTaken: (zone) {
                    return state.players.asMap().entries.any(
                          (other) => other.key != index && other.value.zone == zone,
                        );
                  },
                  onZoneSelected: (zone) async {
                    if (!isRemote) {
                      controller.assignZone(index, zone);
                      return;
                    }
                    await _submitRemoteZoneSelection(
                      context,
                      ref,
                      remoteMatch,
                      zone,
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  bool _isRemoteChasseur(MatchModel match) {
    final hasRemoteContext = match.inviterId != null || match.inviteeId != null;
    return hasRemoteContext && match.mode.toLowerCase() == 'chasseur';
  }

  Future<void> _submitRemoteZoneSelection(
    BuildContext context,
    WidgetRef ref,
    MatchModel match,
    int zone,
  ) async {
    try {
      final api = ref.read(apiClientProvider);
      final service = MatchService(api);
      final updated = await service.updateMatchScore(
        matchId: match.id,
        playerIndex: match.currentPlayerIndex,
        score: 0,
        dartPositions: <Map<String, dynamic>>[
          {
            'x': 0.0,
            'y': 0.0,
            'score': 0,
            'label': 'Z:$zone',
          },
        ],
      );
      ref.read(matchControllerProvider.notifier).loadMatch(updated);
      ref.read(chasseurMatchControllerProvider.notifier).loadRemoteMatch(updated);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de synchroniser la zone.')),
      );
    }
  }
}

class _PlayerZoneSelector extends StatelessWidget {
  const _PlayerZoneSelector({
    required this.playerName,
    required this.selectedZone,
    required this.enabled,
    required this.isZoneTaken,
    required this.onZoneSelected,
  });

  final String playerName;
  final int? selectedZone;
  final bool enabled;
  final bool Function(int zone) isZoneTaken;
  final ValueChanged<int> onZoneSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            playerName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: selectedZone,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.surfaceLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.surfaceLight),
              ),
            ),
            dropdownColor: AppColors.surface,
            items: [
              for (var i = 1; i <= 20; i++)
                DropdownMenuItem<int>(
                  value: i,
                  enabled: !isZoneTaken(i),
                  child: Text('Zone $i'),
                ),
              DropdownMenuItem<int>(
                value: 25,
                enabled: !isZoneTaken(25),
                child: const Text('Bull'),
              ),
            ],
            onChanged: enabled
                ? (value) {
                    if (value != null) {
                      onZoneSelected(value);
                    }
                  }
                : null,
          ),
          if (!enabled)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'En attente de la selection adverse...',
                style: TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
