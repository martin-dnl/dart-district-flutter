import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../controller/tournament_controller.dart';
import '../models/tournament_model.dart';

class TournamentsListScreen extends ConsumerStatefulWidget {
  const TournamentsListScreen({super.key});

  @override
  ConsumerState<TournamentsListScreen> createState() =>
      _TournamentsListScreenState();
}

class _TournamentsListScreenState extends ConsumerState<TournamentsListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(tournamentsListProvider);
    await ref.read(tournamentsListProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final tournamentsAsync = ref.watch(tournamentsListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: Column(
          children: [
            const SizedBox(height: 4),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'A venir'),
                Tab(text: 'En cours'),
                Tab(text: 'Termines'),
              ],
            ),
            Expanded(
              child: tournamentsAsync.when(
                data: (tournaments) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _TournamentTab(
                        tournaments: tournaments
                            .where((t) => t.scheduledAt.isAfter(DateTime.now()))
                            .toList(),
                        onRefresh: _refresh,
                      ),
                      _TournamentTab(
                        tournaments: tournaments
                            .where((t) => t.currentPhase != 'finished')
                            .toList(),
                        onRefresh: _refresh,
                      ),
                      _TournamentTab(
                        tournaments: tournaments
                            .where((t) => t.currentPhase == 'finished')
                            .toList(),
                        onRefresh: _refresh,
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Impossible de charger les tournois.',
                          style: TextStyle(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.35),
                              ),
                            ),
                            child: SelectableText(
                              'Cause technique (debug):\n${error.toString()}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Rafraichir'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TournamentTab extends StatelessWidget {
  const _TournamentTab({required this.tournaments, required this.onRefresh});

  final List<TournamentModel> tournaments;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (tournaments.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                'Aucun tournoi pour cet onglet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemBuilder: (context, index) {
          final tournament = tournaments[index];
          final isFull = tournament.enrolledPlayers >= tournament.maxPlayers;

          return GlassCard(
            onTap: () => context.push('/tournaments/${tournament.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tournament.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(isFull ? 'Complet' : 'Ouvert'),
                      backgroundColor: isFull
                          ? AppColors.error.withValues(alpha: 0.2)
                          : AppColors.success.withValues(alpha: 0.2),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${tournament.mode.toUpperCase()} - ${tournament.finish}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if ((tournament.venueName ?? '').isNotEmpty)
                  Text(
                    tournament.venueName!,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '${tournament.enrolledPlayers}/${tournament.maxPlayers} joueurs',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    const Spacer(),
                    Text(
                      _dateLabel(tournament.scheduledAt),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Frais: ${tournament.entryFee.toStringAsFixed(2)} EUR',
                  style: const TextStyle(color: AppColors.textHint),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemCount: tournaments.length,
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year a $hour:$minute';
  }
}
