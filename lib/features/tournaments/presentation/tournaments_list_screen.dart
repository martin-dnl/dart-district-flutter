import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/neon_modal.dart';
import '../controller/tournament_controller.dart';
import '../data/tournament_service.dart';
import '../models/tournament_model.dart';

class TournamentsListScreen extends ConsumerStatefulWidget {
  const TournamentsListScreen({super.key});

  @override
  ConsumerState<TournamentsListScreen> createState() =>
      _TournamentsListScreenState();
}

class _TournamentsListScreenState extends ConsumerState<TournamentsListScreen>
    with TickerProviderStateMixin {
  late final TabController _rootTabController;
  late final TabController _tournamentTabController;
  late final TabController _rankingTabController;
  late final TextEditingController _tournamentFilterController;
  late final TextEditingController _rankingFilterController;

  Timer? _rankingFilterDebounce;
  Future<List<PlayerLeaderboardEntry>>? _eloFuture;
  Future<List<PlayerLeaderboardEntry>>? _conquestFuture;

  @override
  void initState() {
    super.initState();
    _rootTabController = TabController(length: 2, vsync: this);
    _tournamentTabController = TabController(length: 3, vsync: this);
    _rankingTabController = TabController(length: 2, vsync: this);
    _tournamentFilterController = TextEditingController();
    _rankingFilterController = TextEditingController();
    _rankingFilterController.addListener(_onRankingFilterChanged);
    _reloadLeaderboards();
  }

  @override
  void dispose() {
    _rankingFilterDebounce?.cancel();
    _rankingFilterController.removeListener(_onRankingFilterChanged);
    _rootTabController.dispose();
    _tournamentTabController.dispose();
    _rankingTabController.dispose();
    _tournamentFilterController.dispose();
    _rankingFilterController.dispose();
    super.dispose();
  }

  void _onRankingFilterChanged() {
    _rankingFilterDebounce?.cancel();
    _rankingFilterDebounce = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) {
        return;
      }
      _reloadLeaderboards();
    });
  }

  void _reloadLeaderboards() {
    final service = ref.read(tournamentServiceProvider);
    final query = _rankingFilterController.text.trim();
    final limit = query.isEmpty ? 50 : 200;
    setState(() {
      _eloFuture = service.fetchPlayerLeaderboard(
        metric: 'elo',
        limit: limit,
        query: query.isEmpty ? null : query,
      );
      _conquestFuture = service.fetchPlayerLeaderboard(
        metric: 'conquest',
        limit: limit,
        query: query.isEmpty ? null : query,
      );
    });
  }

  Future<void> _scanTournamentQrAndOpen() async {
    final result = await context.push<Object?>(
      AppRoutes.qrScan,
      extra: {'mode': QrScanMode.tournament.name},
    );
    if (!mounted || result == null) {
      return;
    }

    if (result is Map<String, dynamic> && result['not_found'] == true) {
      await showNeonDialog<void>(
        context: context,
        builder: (_) => const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 40),
              SizedBox(height: 10),
              Text(
                'Tournoi inexistant',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
              Text(
                'Le QR code scanne ne correspond a aucun tournoi connu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final tournamentId = (result is Map<String, dynamic>)
        ? (result['id'] ?? '').toString()
        : '';
    if (tournamentId.isEmpty) {
      return;
    }

    context.push('/tournaments/$tournamentId');
  }

  Future<void> _refresh() async {
    ref.invalidate(tournamentsListProvider);
    await ref.read(tournamentsListProvider.future);
    _reloadLeaderboards();
  }

  @override
  Widget build(BuildContext context) {
    final tournamentsAsync = ref.watch(tournamentsListProvider);
    final tournamentFilter = _tournamentFilterController.text
        .trim()
        .toLowerCase();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: Column(
          children: [
            const SizedBox(height: 4),
            TabBar(
              controller: _rootTabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Tournois'),
                Tab(text: 'Classement'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _rootTabController,
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Liste des tournois',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _SearchInput(
                          controller: _tournamentFilterController,
                          hintText: 'Filtrer les tournois par nom',
                          onChanged: (_) => setState(() {}),
                          onSuffixPressed: _scanTournamentQrAndOpen,
                          suffixIcon: Icons.qr_code_scanner,
                        ),
                      ),
                      TabBar(
                        controller: _tournamentTabController,
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
                            final filteredGlobal = tournamentFilter.isEmpty
                                ? tournaments
                                : tournaments
                                      .where(
                                        (tournament) => tournament.name
                                            .toLowerCase()
                                            .contains(tournamentFilter),
                                      )
                                      .toList(growable: false);

                            final upcoming = tournamentFilter.isEmpty
                                ? tournaments
                                      .where(
                                        (t) => t.scheduledAt.isAfter(
                                          DateTime.now(),
                                        ),
                                      )
                                      .toList(growable: false)
                                : filteredGlobal;

                            final ongoing = tournamentFilter.isEmpty
                                ? tournaments
                                      .where(
                                        (t) => t.currentPhase != 'finished',
                                      )
                                      .toList(growable: false)
                                : filteredGlobal;

                            final finished = tournamentFilter.isEmpty
                                ? tournaments
                                      .where(
                                        (t) => t.currentPhase == 'finished',
                                      )
                                      .toList(growable: false)
                                : filteredGlobal;

                            return TabBarView(
                              controller: _tournamentTabController,
                              children: [
                                _TournamentTab(
                                  tournaments: upcoming,
                                  onRefresh: _refresh,
                                ),
                                _TournamentTab(
                                  tournaments: ongoing,
                                  onRefresh: _refresh,
                                ),
                                _TournamentTab(
                                  tournaments: finished,
                                  onRefresh: _refresh,
                                ),
                              ],
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stackTrace) =>
                              _ErrorPanel(error: error, onRefresh: _refresh),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Classement joueurs',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _SearchInput(
                          controller: _rankingFilterController,
                          hintText: 'Filtrer les joueurs par nom',
                          onChanged: (_) {},
                          suffixIcon: Icons.search,
                        ),
                      ),
                      TabBar(
                        controller: _rankingTabController,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textSecondary,
                        indicatorColor: AppColors.primary,
                        tabs: const [
                          Tab(text: 'ELO'),
                          Tab(text: 'Conquete'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _rankingTabController,
                          children: [
                            _LeaderboardTab(
                              future: _eloFuture,
                              metric: 'elo',
                              onRefresh: _refresh,
                            ),
                            _LeaderboardTab(
                              future: _conquestFuture,
                              metric: 'conquest',
                              onRefresh: _refresh,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRefresh});

  final Object error;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Rafraichir'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.suffixIcon,
    this.onSuffixPressed,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final IconData suffixIcon;
  final VoidCallback? onSuffixPressed;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          onPressed: onSuffixPressed,
          icon: Icon(suffixIcon, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab({
    required this.future,
    required this.metric,
    required this.onRefresh,
  });

  final Future<List<PlayerLeaderboardEntry>>? future;
  final String metric;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<List<PlayerLeaderboardEntry>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Recharger le classement'),
            ),
          );
        }

        final entries = snapshot.data ?? const <PlayerLeaderboardEntry>[];
        if (entries.isEmpty) {
          return const Center(
            child: Text(
              'Aucun joueur trouve.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        final bool eloMode = metric == 'elo';
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final points = eloMode ? entry.elo : entry.conquestScore;
            final pointsColor = eloMode ? AppColors.primary : AppColors.accent;
            return GlassCard(
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          context.push(AppRoutes.profile, extra: entry.id),
                      child: Text(
                        entry.username,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!eloMode)
                        Icon(Icons.emoji_events, size: 16, color: pointsColor),
                      if (!eloMode) const SizedBox(width: 4),
                      Text(
                        '$points',
                        style: TextStyle(
                          color: pointsColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
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
