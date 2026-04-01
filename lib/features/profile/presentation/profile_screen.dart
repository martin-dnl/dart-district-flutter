import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/network/api_providers.dart';
import '../../../shared/widgets/match_history_list.dart';
import '../../../shared/widgets/player_avatar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/profile_controller.dart';
import '../data/profile_service.dart';
import '../widgets/elo_chart.dart';
import '../widgets/badge_grid.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _changeAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) {
      return;
    }

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 88,
    );

    if (picked == null || !mounted) {
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      final service = ProfileService(api);
      await service.uploadAvatar(File(picked.path));
      await ref.read(authControllerProvider.notifier).refreshCurrentUser();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo de profil mise a jour')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de mettre a jour la photo')),
      );
    }
  }

  void _showMyQrCode() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user.username,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: user.id,
              version: QrVersions.auto,
              size: 200,
              eyeStyle: const QrEyeStyle(color: AppColors.textPrimary),
              dataModuleStyle: const QrDataModuleStyle(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Faites scanner ce code pour etre ajoute ou defie',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profileState = ref.watch(profileControllerProvider);
    final recentMatches = profileState.matchHistory.take(5).toList();
    final losses =
        (user?.stats.matchesPlayed ?? 0) - (user?.stats.matchesWon ?? 0);

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
                    Row(
                      children: [
                        IconButton(
                          onPressed: _showMyQrCode,
                          icon: const Icon(
                            Icons.qr_code_2,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => context.push(AppRoutes.settings),
                          icon: const Icon(
                            Icons.settings_outlined,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    GestureDetector(
                      onTap: _changeAvatar,
                      child: PlayerAvatar(
                        name: user?.username ?? 'Joueur',
                        imageUrl: user?.avatarUrl,
                        size: 90,
                        showBorder: true,
                      ),
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
                          horizontal: 10,
                          vertical: 4,
                        ),
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
                        label: 'Defaites',
                        value: '$losses',
                        icon: Icons.close,
                        valueColor: AppColors.error,
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
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Moyenne',
                        value:
                            user?.stats.averageScore.toStringAsFixed(1) ?? '0',
                        icon: Icons.analytics,
                        valueColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatCard(
                        label: 'Checkout',
                        value:
                            '${user?.stats.checkoutRate.toStringAsFixed(0) ?? 0}%',
                        icon: Icons.check_circle,
                        valueColor: AppColors.secondary,
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
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: '180s',
                        value: '${user?.stats.highest180s ?? 0}',
                        icon: Icons.stars,
                        valueColor: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatCard(
                        label: '140+',
                        value: '${user?.stats.count140Plus ?? 0}',
                        icon: Icons.local_fire_department,
                        valueColor: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatCard(
                        label: '100+',
                        value: '${user?.stats.count100Plus ?? 0}',
                        icon: Icons.bolt,
                        valueColor: AppColors.primary,
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
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Badges',
                actionText: 'Voir tout',
                onAction: () => context.push(AppRoutes.badges),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: BadgeGrid(badges: profileState.badges, maxDisplay: 4),
              ),
            ),

            // Match history
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Historique des matchs'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MatchHistoryList(
                  matches: recentMatches,
                  onMatchTap: (matchId) =>
                      context.push('/match/$matchId/report'),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
