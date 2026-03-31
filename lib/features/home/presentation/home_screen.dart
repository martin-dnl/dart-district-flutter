import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/home_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final homeState = ref.watch(homeControllerProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _HomeHeader(
                    clubName: homeState.clubName,
                    location: homeState.location,
                    avatarUrl: user?.avatarUrl,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _PendingMatchCard(subtitle: homeState.pendingMatch),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.location_city,
                          title: 'Territoires controles',
                          value: '${homeState.territoriesControlled}',
                          subtitle: 'Carte live',
                          accent: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.emoji_events,
                          title: 'Points de conquete',
                          value: '${homeState.conquestPoints}',
                          subtitle: 'Rang #${homeState.clubRank}',
                          accent: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _SectionTitle(title: 'Forme Recente', action: 'Voir l\'historique'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _RecentFormCard(
                    recentResults: homeState.recentResults,
                    recentRecord: homeState.recentRecord,
                    recentOpponent: homeState.recentOpponent,
                    recentScore: homeState.recentScore,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _QuickActions(
                    onOpenMap: () => context.go(AppRoutes.map),
                    onLaunchMatch: () => context.go(AppRoutes.play),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _SectionTitle(title: 'Prochains Tournois', action: 'Voir tout'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _TournamentCard(
                    tournamentType: homeState.tournamentType,
                    tournamentTitle: homeState.tournamentTitle,
                    tournamentCountdown: homeState.tournamentCountdown,
                    tournamentSlots: homeState.tournamentSlots,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _SectionTitle(title: 'Effectif Actif'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ActiveMembersCard(members: homeState.activeMembers),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String clubName;
  final String location;
  final String? avatarUrl;

  const _HomeHeader({
    required this.clubName,
    required this.location,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.secondary, width: 1.2),
          ),
          child: ClipOval(
            child: avatarUrl != null
                ? Image.network(avatarUrl!, fit: BoxFit.cover)
                : Container(
                    color: AppColors.surfaceLight,
                    child: const Icon(Icons.person, color: AppColors.textSecondary),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                clubName,
                style: GoogleFonts.rajdhani(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                location,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
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
          child: const Icon(Icons.notifications_none, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

class _PendingMatchCard extends StatelessWidget {
  const _PendingMatchCard({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.error.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.42)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error.withValues(alpha: 0.2),
            ),
            child: const Icon(Icons.priority_high, color: AppColors.error),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match a valider',
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color accent;

  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
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
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;

  const _SectionTitle({required this.title, this.action});

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
          Text(
            action!,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _RecentFormCard extends StatelessWidget {
  const _RecentFormCard({
    required this.recentResults,
    required this.recentRecord,
    required this.recentOpponent,
    required this.recentScore,
  });

  final List<bool> recentResults;
  final String recentRecord;
  final String recentOpponent;
  final String recentScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ...(recentResults.isEmpty
                      ? <String>['-']
                      : recentResults
                          .take(5)
                          .map((r) => r ? 'V' : 'D')
                          .toList())
                  .map(
                (status) => Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: status == 'V'
                        ? AppColors.success.withValues(alpha: 0.18)
                        : status == 'D'
                            ? AppColors.error.withValues(alpha: 0.18)
                            : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: status == 'V'
                          ? AppColors.success.withValues(alpha: 0.35)
                          : status == 'D'
                              ? AppColors.error.withValues(alpha: 0.35)
                              : AppColors.stroke,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      status,
                      style: GoogleFonts.manrope(
                        color: status == 'V'
                            ? AppColors.success
                            : status == 'D'
                                ? AppColors.error
                                : AppColors.textHint,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                recentRecord,
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Row(
              children: [
                const CircleAvatar(radius: 14, backgroundColor: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recentOpponent,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    recentScore,
                    style: GoogleFonts.manrope(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onOpenMap;
  final VoidCallback onLaunchMatch;

  const _QuickActions({
    required this.onOpenMap,
    required this.onLaunchMatch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Actions Rapides'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _QuickActionTile(
                icon: Icons.add,
                label: 'Creer\nTournoi',
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionTile(
                icon: Icons.map,
                label: 'Ouvrir\nCarte',
                onTap: onOpenMap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionTile(
                icon: Icons.play_arrow_rounded,
                label: 'Lancer\nMatch',
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
          border: Border.all(color: isPrimary ? Colors.transparent : AppColors.stroke),
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

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({
    required this.tournamentType,
    required this.tournamentTitle,
    required this.tournamentCountdown,
    required this.tournamentSlots,
  });

  final String tournamentType;
  final String tournamentTitle;
  final String tournamentCountdown;
  final String tournamentSlots;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tournamentType,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                tournamentSlots,
                style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tournamentTitle,
            style: GoogleFonts.rajdhani(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tournamentCountdown,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceLight,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
              child: const Text('S\'inscrire'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveMembersCard extends StatelessWidget {
  const _ActiveMembersCard({required this.members});

  final List<Map<String, dynamic>> members;

  @override
  Widget build(BuildContext context) {
    final resolvedMembers = members.isEmpty
        ? const [
            {'name': '---', 'role': 'player'}
          ]
        : members;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ...resolvedMembers.map(
            (member) => Column(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surfaceLight,
                  child: Text(
                    ((member['name'] ?? '?').toString()).substring(0, 1),
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (member['name'] ?? '').toString(),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((member['role'] ?? '').toString() == 'captain')
                  Text(
                    '(Cap)',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: const Icon(Icons.add, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'Inviter',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
