import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_colors.dart';
import '../../../features/auth/controller/auth_controller.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/player_avatar.dart';
import '../controller/tournament_controller.dart';
import '../data/tournament_service.dart';
import '../models/bracket_match_model.dart';
import '../models/pool_model.dart';
import '../models/tournament_model.dart';
import '../widgets/bracket_view.dart';

class TournamentDetailScreen extends ConsumerWidget {
  const TournamentDetailScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(tournamentDetailProvider(tournamentId));
    final poolsAsync = ref.watch(tournamentPoolsProvider(tournamentId));
    final bracketAsync = ref.watch(tournamentBracketProvider(tournamentId));

    return AppScaffold(
      child: detailAsync.when(
          data: (detail) {
            final isCreator =
                ref.read(currentUserProvider)?.id ==
                detail.tournament.creatorId;
            final canDisqualify =
                isCreator && detail.tournament.currentPhase != 'registration';

            return DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    tabs: [
                      Tab(text: 'Joueurs'),
                      Tab(text: 'Infos'),
                      Tab(text: 'Poules'),
                      Tab(text: 'Bracket'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _PlayersTab(
                          players: detail.players,
                          tournamentId: tournamentId,
                          canDisqualify: canDisqualify,
                        ),
                        _InfoTab(
                          tournament: detail.tournament,
                          onRegisterToggle: () async {
                            final service = ref.read(tournamentServiceProvider);
                            if (detail.tournament.isRegistered) {
                              await service.unregister(tournamentId);
                            } else {
                              await service.register(tournamentId);
                            }
                            ref.invalidate(tournamentDetailProvider(tournamentId));
                            ref.invalidate(tournamentsListProvider);
                          },
                        ),
                        _PoolsTab(poolsAsync: poolsAsync),
                        _BracketTab(bracketAsync: bracketAsync),
                      ],
                    ),
                  ),
                  if (isCreator)
                    _AdminActions(
                      tournamentId: tournamentId,
                      phase: detail.tournament.currentPhase,
                      enrolledPlayers: detail.tournament.enrolledPlayers,
                    ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => const Center(
            child: Text(
              'Erreur de chargement du tournoi.',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ),
    );
  }
}

class _InfoTab extends ConsumerWidget {
  const _InfoTab({required this.tournament, required this.onRegisterToggle});

  final TournamentModel tournament;
  final Future<void> Function() onRegisterToggle;

  String _phaseLabel(String phase) {
    switch (phase.toLowerCase()) {
      case 'registration':
        return 'Inscriptions';
      case 'pools':
        return 'Poules';
      case 'bracket':
        return 'Bracket';
      case 'completed':
        return 'Termine';
      default:
        return phase;
    }
  }

  Color _phaseColor(String phase) {
    switch (phase.toLowerCase()) {
      case 'registration':
        return AppColors.primary;
      case 'pools':
        return AppColors.info;
      case 'bracket':
        return AppColors.warning;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> handleRegisterToggle() async {
      if (!tournament.isRegistered) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Rejoindre ce tournoi ?'),
            content: Text(
              'Confirmer votre inscription a "${tournament.name}" ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Rejoindre'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
      }

      try {
        await onRegisterToggle();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tournament.isRegistered
                  ? 'Desinscription effectuee.'
                  : 'Inscription confirmee.',
            ),
          ),
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action impossible pour le moment.')),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tournament.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${tournament.mode.toUpperCase()} • ${tournament.finish} • ${tournament.city ?? 'Ville inconnue'}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _phaseColor(tournament.currentPhase).withValues(
                    alpha: 0.14,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _phaseColor(tournament.currentPhase).withValues(
                      alpha: 0.42,
                    ),
                  ),
                ),
                child: Text(
                  'Phase: ${_phaseLabel(tournament.currentPhase)}',
                  style: TextStyle(
                    color: _phaseColor(tournament.currentPhase),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _InfoRow(
                label: 'Createur',
                value: tournament.creatorUsername ?? 'Utilisateur inconnu',
              ),
              _InfoRow(label: 'Format', value: tournament.format),
              _InfoRow(
                label: 'Joueurs',
                value:
                    '${tournament.enrolledPlayers} / ${tournament.maxPlayers}',
              ),
              _InfoRow(
                label: 'Frais',
                value: '${tournament.entryFee.toStringAsFixed(2)} EUR',
              ),
              if (tournament.poolCount != null)
                _InfoRow(
                  label: 'Poules',
                  value:
                      '${tournament.poolCount} (${tournament.playersPerPool ?? '-'} joueurs/poule, ${tournament.qualifiedPerPool ?? '-'} qualifies)',
                ),
              if (tournament.legsPerSetPool != null)
                _InfoRow(
                  label: 'Config poules',
                  value:
                      'BO ${tournament.legsPerSetPool} • ${tournament.setsToWinPool ?? 1} set(s)',
                ),
              if (tournament.legsPerSetBracket != null)
                _InfoRow(
                  label: 'Config bracket',
                  value:
                      'BO ${tournament.legsPerSetBracket} • ${tournament.setsToWinBracket ?? 1} set(s)',
                ),
              if ((tournament.description ?? '').trim().isNotEmpty)
                _InfoRow(
                  label: 'Description',
                  value: tournament.description!.trim(),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: handleRegisterToggle,
                  child: Text(
                    tournament.isRegistered ? 'Se desinscrire' : 'Rejoindre',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textHint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayersTab extends ConsumerWidget {
  const _PlayersTab({
    required this.players,
    required this.tournamentId,
    required this.canDisqualify,
  });

  final List<TournamentPlayerModel> players;
  final String tournamentId;
  final bool canDisqualify;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (players.isEmpty) {
      return const Center(
        child: Text(
          'Aucun joueur inscrit.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (_, index) {
        final player = players[index];
        return GlassCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: PlayerAvatar(
              name: player.username,
              imageUrl: player.avatarUrl,
              size: 38,
            ),
            title: Text(
              player.username,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            subtitle: Text(
              'ELO ${player.elo ?? 1000} • Seed ${player.seed ?? '-'}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (player.isQualified)
                  const Icon(Icons.verified, color: AppColors.success),
                if (player.isDisqualified)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.block, color: AppColors.error),
                  ),
                if (canDisqualify && !player.isDisqualified)
                  IconButton(
                    tooltip: 'Disqualifier ${player.username}',
                    onPressed: () async {
                      final reasonCtrl = TextEditingController();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text('Disqualifier ${player.username}'),
                          content: TextField(
                            controller: reasonCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Raison',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Annuler'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Valider'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;

                      try {
                        await ref
                            .read(tournamentServiceProvider)
                            .disqualify(
                              tournamentId: tournamentId,
                              playerId: player.userId,
                              reason: reasonCtrl.text.trim().isEmpty
                                  ? 'Disqualification admin'
                                  : reasonCtrl.text.trim(),
                            );
                        ref.invalidate(tournamentDetailProvider(tournamentId));
                        ref.invalidate(tournamentPoolsProvider(tournamentId));
                        ref.invalidate(tournamentBracketProvider(tournamentId));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Joueur disqualifie.')),
                        );
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Action admin impossible.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.gavel_rounded),
                  ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemCount: players.length,
    );
  }
}

class _PoolsTab extends StatelessWidget {
  const _PoolsTab({required this.poolsAsync});

  final AsyncValue<List<PoolModel>> poolsAsync;

  @override
  Widget build(BuildContext context) {
    return poolsAsync.when(
      data: (pools) {
        if (pools.isEmpty) {
          return const Center(
            child: Text(
              'Les poules seront generees a la fin des inscriptions.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: pools.length,
          itemBuilder: (_, index) {
            final pool = pools[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Poule ${pool.poolName}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('#')),
                          DataColumn(label: Text('Joueur')),
                          DataColumn(label: Text('J')),
                          DataColumn(label: Text('V')),
                          DataColumn(label: Text('LW')),
                          DataColumn(label: Text('LL')),
                          DataColumn(label: Text('+/-')),
                          DataColumn(label: Text('Pts')),
                        ],
                        rows: pool.standings
                            .asMap()
                            .entries
                            .map(
                              (entry) => DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      (entry.value.rank ?? (entry.key + 1))
                                          .toString(),
                                    ),
                                  ),
                                  DataCell(Text(entry.value.username)),
                                  DataCell(
                                    Text(entry.value.matchesPlayed.toString()),
                                  ),
                                  DataCell(
                                    Text(entry.value.matchesWon.toString()),
                                  ),
                                  DataCell(
                                    Text(entry.value.legsWon.toString()),
                                  ),
                                  DataCell(
                                    Text(entry.value.legsLost.toString()),
                                  ),
                                  DataCell(
                                    Text(entry.value.legDifference.toString()),
                                  ),
                                  DataCell(Text(entry.value.points.toString())),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const Center(
        child: Text(
          'Impossible de charger les poules.',
          style: TextStyle(color: AppColors.error),
        ),
      ),
    );
  }
}

class _BracketTab extends StatelessWidget {
  const _BracketTab({required this.bracketAsync});

  final AsyncValue<List<BracketMatchModel>> bracketAsync;

  @override
  Widget build(BuildContext context) {
    return bracketAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return const Center(
            child: Text(
              'Le bracket sera genere apres les poules.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return BracketView(matches: matches);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const Center(
        child: Text(
          'Impossible de charger le bracket.',
          style: TextStyle(color: AppColors.error),
        ),
      ),
    );
  }
}

class _AdminActions extends ConsumerWidget {
  const _AdminActions({
    required this.tournamentId,
    required this.phase,
    required this.enrolledPlayers,
  });

  final String tournamentId;
  final String phase;
  final int enrolledPlayers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> runAction(Future<void> Function() action) async {
      try {
        await action();
        ref.invalidate(tournamentDetailProvider(tournamentId));
        ref.invalidate(tournamentPoolsProvider(tournamentId));
        ref.invalidate(tournamentBracketProvider(tournamentId));
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action admin impossible.')),
        );
      }
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(
          children: [
            if (phase == 'registration')
              Expanded(
                child: FilledButton(
                  onPressed: enrolledPlayers > 1
                      ? () => runAction(
                          () => ref
                              .read(tournamentServiceProvider)
                              .generatePools(tournamentId),
                        )
                      : null,
                  child: const Text('Demarrer le tournoi'),
                ),
              ),
            if (phase == 'pools')
              Expanded(
                child: FilledButton(
                  onPressed: () => runAction(
                    () => ref
                        .read(tournamentServiceProvider)
                        .generateBracket(tournamentId),
                  ),
                  child: const Text('Passer au bracket'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
