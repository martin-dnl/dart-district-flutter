import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../shared/widgets/section_header.dart';
import '../widgets/game_mode_card.dart';
import '../widgets/ongoing_matches_tile.dart';

class PlayScreen extends ConsumerWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: SectionHeader(title: 'Mode jeu'),
            ),
            // X01 Modes
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: GameModeCard(
                        title: '301',
                        subtitle: 'Classique',
                        icon: Icons.gps_fixed,
                        color: AppColors.primary,
                        onTap: () =>
                            context.push(AppRoutes.gameSetup, extra: '301'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GameModeCard(
                        title: '501',
                        subtitle: 'Standard',
                        icon: Icons.gps_fixed,
                        color: AppColors.secondary,
                        onTap: () =>
                            context.push(AppRoutes.gameSetup, extra: '501'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GameModeCard(
                        title: '701',
                        subtitle: 'Long',
                        icon: Icons.gps_fixed,
                        color: AppColors.accent,
                        onTap: () =>
                            context.push(AppRoutes.gameSetup, extra: '701'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _LargeGameModeCard(
                      title: 'Cricket',
                      subtitle:
                          'Fermez les numéros 15-20 et le Bull avant votre adversaire',
                      icon: Icons.bug_report,
                      color: AppColors.success,
                      onTap: () =>
                          context.push(AppRoutes.gameSetup, extra: 'Cricket'),
                    ),
                    const SizedBox(height: 12),
                    _LargeGameModeCard(
                      title: 'Chasseur',
                      subtitle:
                          'Un chasseur, une proie. Touchez pour éliminer !',
                      icon: Icons.track_changes,
                      color: AppColors.error,
                      onTap: () =>
                          context.push(AppRoutes.gameSetup, extra: 'Chasseur'),
                    ),
                  ],
                ),
              ),
            ),
            // Ongoing Matches
            SliverToBoxAdapter(child: OngoingMatchesTile()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _LargeGameModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _LargeGameModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLight, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}
