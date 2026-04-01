import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_colors.dart';
import '../../../features/auth/controller/auth_controller.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail tournoi'),
        backgroundColor: AppColors.background,
      ),
      backgroundColor: AppColors.background,
      body: detailAsync.when(
        data: (detail) {
          final isCreator =
              ref.read(currentUserProvider)?.id == detail.tournament.creatorId;

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                _HeaderCard(
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
                const TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: [
                    Tab(text: 'Joueurs'),
                    Tab(text: 'Poules'),
                    Tab(text: 'Bracket'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _PlayersTab(players: detail.players),
                      _PoolsTab(poolsAsync: poolsAsync),
                      _BracketTab(bracketAsync: bracketAsync),
                    ],
                  ),
                ),
                if (isCreator)
                  _AdminActions(
                    tournamentId: tournamentId,
                    phase: detail.tournament.currentPhase,
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

class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({required this.tournament, required this.onRegisterToggle});

  final TournamentModel tournament;
  final Future<void> Function() onRegisterToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tournament.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${tournament.mode.toUpperCase()} • ${tournament.finish} • ${tournament.city ?? 'Ville inconnue'}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              '${tournament.enrolledPlayers} / ${tournament.maxPlayers} joueurs',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                try {
                  await onRegisterToggle();
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Action impossible pour le moment.'),
                    ),
                  );
                }
              },
              child: Text(
                tournament.isRegistered ? 'Se desinscrire' : 'S\'inscrire',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayersTab extends StatelessWidget {
  const _PlayersTab({required this.players});

  final List<TournamentPlayerModel> players;

  @override
  Widget build(BuildContext context) {
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
            trailing: player.isQualified
                ? const Icon(Icons.verified, color: AppColors.success)
                : null,
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
  const _AdminActions({required this.tournamentId, required this.phase});

  final String tournamentId;
  final String phase;

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
                  onPressed: () => runAction(
                    () => ref
                        .read(tournamentServiceProvider)
                        .generatePools(tournamentId),
                  ),
                  child: const Text('Generer les poules'),
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
            if (phase != 'finished') ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final reasonCtrl = TextEditingController();
                  final playerCtrl = TextEditingController();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Disqualifier un joueur'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: playerCtrl,
                            decoration: const InputDecoration(
                              labelText: 'User ID joueur',
                            ),
                          ),
                          TextField(
                            controller: reasonCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Raison',
                            ),
                          ),
                        ],
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
                  if (confirmed != true || playerCtrl.text.trim().isEmpty) {
                    return;
                  }
                  await runAction(
                    () => ref
                        .read(tournamentServiceProvider)
                        .disqualify(
                          tournamentId: tournamentId,
                          playerId: playerCtrl.text.trim(),
                          reason: reasonCtrl.text.trim().isEmpty
                              ? 'Disqualification admin'
                              : reasonCtrl.text.trim(),
                        ),
                  );
                },
                child: const Text('Disqualifier'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
