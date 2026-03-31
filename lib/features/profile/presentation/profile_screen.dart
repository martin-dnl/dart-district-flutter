import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../shared/widgets/player_avatar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/profile_controller.dart';
import '../widgets/elo_chart.dart';
import '../widgets/match_history_tile.dart';
import '../widgets/badge_grid.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileState = ref.watch(profileControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Profile header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Settings icon
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: () => context.push(AppRoutes.settings),
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),

                    // Avatar
                    PlayerAvatar(
                      name: user?.username ?? 'Joueur',
                      imageUrl: user?.avatarUrl,
                      size: 90,
                      showBorder: true,
                    ),
                    const SizedBox(height: 14),

                    // Username
                    Text(
                      user?.username ?? 'Joueur',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (user?.clubName != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          user!.clubName!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Stats cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'ELO',
                        value: '${user?.elo ?? 1000}',
                        icon: Icons.trending_up,
                        valueColor: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatCard(
                        label: 'Victoires',
                        value: '${user?.stats.matchesWon ?? 0}',
                        icon: Icons.emoji_events,
                        valueColor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatCard(
                        label: 'Moyenne',
                        value:
                            user?.stats.averageScore.toStringAsFixed(1) ?? '0',
                        icon: Icons.analytics,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatCard(
                        label: 'Checkout',
                        value:
                            '${user?.stats.checkoutRate.toStringAsFixed(0) ?? 0}%',
                        icon: Icons.check_circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ELO chart
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Progression ELO'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: EloChart(eloHistory: profileState.eloHistory),
              ),
            ),

            // Badges
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Badges'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: BadgeGrid(badges: profileState.badges),
              ),
            ),

            // Match history
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Historique des matchs'),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final match = profileState.matchHistory[index];
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: MatchHistoryTile(match: match),
                  );
                },
                childCount: profileState.matchHistory.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
