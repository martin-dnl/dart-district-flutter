import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/config/translation_service.dart';
import '../../match/controller/ongoing_matches_controller.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/home_controller.dart';
import '../controller/my_active_tournaments_provider.dart';
import '../controller/recent_ranked_matches_provider.dart';
import '../widgets/tournament_tile.dart';
import '../../../shared/models/match_history_summary.dart';
import '../../../shared/widgets/match_history_list.dart';
import '../../../shared/widgets/player_avatar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final homeState = ref.watch(homeControllerProvider);
    final recentRankedMatches = ref.watch(recentRankedMatchesProvider);
    final activeTournaments = ref.watch(myActiveTournamentsProvider);
    final showTournamentsSection = activeTournaments.maybeWhen(
      data: (items) => items.isNotEmpty,
      loading: () => true,
      orElse: () => false,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              final loadHome = ref.read(homeControllerProvider.notifier).load();
              ref.invalidate(recentRankedMatchesProvider);
              ref.invalidate(myActiveTournamentsProvider);
              await Future.wait([
                loadHome,
                ref.read(recentRankedMatchesProvider.future),
                ref.read(myActiveTournamentsProvider.future),
                ref.read(ongoingMatchesControllerProvider.notifier).refresh(),
              ]);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: _HomeHeader(
                      username: user?.username ?? 'Joueur',
                      clubName: user?.clubName,
                      avatarUrl: user?.avatarUrl,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.location_city,
                            title: t(
                              'SCREEN.HOME.TERRITORIES_CONTROLLED',
                              fallback: 'Territoires controles',
                            ),
                            value: '${homeState.territoriesControlled}',
                            subtitle: t(
                              'SCREEN.HOME.LIVE_MAP',
                              fallback: 'Carte live',
                            ),
                            accent: AppColors.secondary,
                            onTap: () => context.go(AppRoutes.map),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.emoji_events,
                            title: t(
                              'SCREEN.HOME.CONQUEST_POINTS',
                              fallback: 'Points de conquete',
                            ),
                            value: '${user?.conquestScore ?? 0}',
                            subtitle:
                                '${t('SCREEN.HOME.RANK', fallback: 'Rang')} #${homeState.clubRank}',
                            accent: AppColors.accent,
                            onTap: () {
                              final clubId = user?.clubId;
                              if (clubId != null && clubId.isNotEmpty) {
                                context.push(
                                  AppRoutes.clubDetail.replaceFirst(
                                    ':id',
                                    clubId,
                                  ),
                                );
                                return;
                              }
                              context.go(AppRoutes.club);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 18)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _QuickActions(
                      isGuest: user?.isGuest ?? false,
                      onOpenMap: () => context.go(AppRoutes.map),
                      onLaunchMatch: () => context.go(AppRoutes.play),
                      onCreateTournament: () =>
                          context.push(AppRoutes.tournamentCreate),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 18)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SectionTitle(
                      title: t(
                        'SCREEN.HOME.LAST_MATCHES',
                        fallback: 'Dernieres parties',
                      ),
                      action: t(
                        'SCREEN.HOME.VIEW_HISTORY',
                        fallback: 'Voir l\'historique',
                      ),
                      onActionTap: () => context.push(AppRoutes.matchHistory),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: recentRankedMatches.when(
                      data: (matches) => _RecentFormCard(matches: matches),
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (_, _) => _RecentFormCard(
                        matches: const <MatchHistorySummary>[],
                      ),
                    ),
                  ),
                ),
                if (showTournamentsSection)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SectionTitle(
                        title: t(
                          'SCREEN.HOME.UPCOMING_TOURNAMENTS',
                          fallback: 'Prochains Tournois',
                        ),
                        action: t('SCREEN.HOME.VIEW_ALL', fallback: 'Voir tout'),
                        onActionTap: () => context.go(AppRoutes.tournaments),
                      ),
                    ),
                  ),
                if (showTournamentsSection)
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                if (showTournamentsSection)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: activeTournaments.when(
                        data: (tournaments) {
                          if (tournaments.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final tournament = tournaments.first;
                          return TournamentTile(
                            type: (tournament['is_territorial'] == true)
                                  ? t(
                                      'SCREEN.TOURNAMENTS.TYPE_TERRITORIAL',
                                      fallback: 'Territorial',
                                    )
                                  : t('SCREEN.TOURNAMENTS.TYPE_LOCAL', fallback: 'Local'),
                              name: (tournament['name'] ??
                                      t(
                                        'SCREEN.TOURNAMENTS.IN_PROGRESS',
                                        fallback: 'Tournoi en cours',
                                      ))
                                .toString(),
                            scheduleLabel:
                                  (tournament['scheduled_at_label'] ??
                                          t(
                                            'SCREEN.TOURNAMENTS.IN_PROGRESS_SHORT',
                                            fallback: 'En cours',
                                          ))
                                    .toString(),
                            slotsLabel:
                                '${(tournament['enrolled_players'] ?? 0).toString()}/${(tournament['max_players'] ?? 0).toString()}',
                            onTap: () {
                              final id = tournament['id']?.toString();
                              if (id != null && id.isNotEmpty) {
                                context.push('/tournaments/$id');
                                return;
                              }
                              context.go(AppRoutes.tournaments);
                            },
                          );
                        },
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (_, _) => _TournamentPlaceholder(
                          type: homeState.tournamentType,
                          title: homeState.tournamentTitle,
                          countdown: homeState.tournamentCountdown,
                          slots: homeState.tournamentSlots,
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 18)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String username;
  final String? clubName;
  final String? avatarUrl;

  const _HomeHeader({
    required this.username,
    required this.clubName,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.push(AppRoutes.profile),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  PlayerAvatar(
                    imageUrl: avatarUrl,
                    name: username,
                    size: 44,
                    showBorder: true,
                    borderColor: AppColors.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (clubName != null && clubName!.trim().isNotEmpty)
                          Text(
                            clubName!,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: AppColors.stroke),
          ),
          child: const Icon(
            Icons.notifications_none,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: accent, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: GoogleFonts.rajdhani(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onActionTap;

  const _SectionTitle({required this.title, this.action, this.onActionTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.rajdhani(
              fontSize: 33,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (action != null)
          InkWell(
            onTap: onActionTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                action!,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentFormCard extends StatelessWidget {
  const _RecentFormCard({required this.matches});

  final List<MatchHistorySummary> matches;

  @override
  Widget build(BuildContext context) {
    final recent = matches.take(5).toList();
    final wins = recent.where((m) => m.won).length;
    final defeats = recent.length - wins;
    final winRate = recent.isEmpty ? 0 : ((wins / recent.length) * 100).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$winRate% ${t('SCREEN.HOME.WINS', fallback: 'Victoires')} (${wins}V - ${defeats}D)',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            Text(
              t('SCREEN.HOME.NO_RANKED_MATCH', fallback: 'Aucun match classe termine'),
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            )
          else
            MatchHistoryList(matches: recent),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final bool isGuest;
  final VoidCallback onOpenMap;
  final VoidCallback onLaunchMatch;
  final VoidCallback onCreateTournament;

  const _QuickActions({
    required this.isGuest,
    required this.onOpenMap,
    required this.onLaunchMatch,
    required this.onCreateTournament,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: t('SCREEN.HOME.QUICK_ACTIONS', fallback: 'Actions Rapides'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (!isGuest)
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.add,
                  label: t(
                    'SCREEN.TOURNAMENTS.CREATE',
                    fallback: 'Creer\nTournoi',
                  ),
                  onTap: onCreateTournament,
                ),
              ),
            if (!isGuest) const SizedBox(width: 10),
            Expanded(
              child: _QuickActionTile(
                icon: Icons.map,
                  label: t('SCREEN.HOME.OPEN_MAP', fallback: 'Ouvrir\nCarte'),
                onTap: onOpenMap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionTile(
                icon: Icons.play_arrow_rounded,
                label: t('SCREEN.PLAY.START_MATCH', fallback: 'Lancer\nMatch'),
                isPrimary: true,
                onTap: onLaunchMatch,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary ? Colors.transparent : AppColors.stroke,
          ),
          color: isPrimary ? AppColors.secondary : AppColors.surface,
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TournamentPlaceholder extends StatelessWidget {
  const _TournamentPlaceholder({
    required this.type,
    required this.title,
    required this.countdown,
    required this.slots,
  });

  final String type;
  final String title;
  final String countdown;
  final String slots;

  @override
  Widget build(BuildContext context) {
    return TournamentTile(
      type: type,
      name: title,
      scheduleLabel: countdown,
      slotsLabel: slots,
      onTap: () => context.go(AppRoutes.tournaments),
    );
  }
}
