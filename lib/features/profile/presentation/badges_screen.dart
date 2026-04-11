import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/translation_service.dart';
import '../controller/profile_controller.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(profileControllerProvider).badges;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t('SCREEN.BADGES.TITLE', fallback: 'Mes Badges')),
        backgroundColor: AppColors.background,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: badges.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (context, index) {
          final badge = badges[index];
          return Opacity(
            opacity: badge.unlocked ? 1 : 0.3,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge.difficulty,
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ColorFiltered(
                        colorFilter: badge.unlocked
                            ? const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.multiply,
                              )
                            : const ColorFilter.mode(
                                Colors.grey,
                                BlendMode.saturation,
                              ),
                        child: _BadgeVisual(icon: badge.icon),
                      ),
                      if (!badge.unlocked)
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: AppColors.textHint.withValues(alpha: 0.8),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    badge.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    badge.description,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _earnedLabel(badge),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _earnedLabel(AchievementBadge badge) {
    if (!badge.unlocked || badge.earnedAt == null) {
      return t('SCREEN.BADGES.NOT_EARNED', fallback: 'Non obtenu');
    }

    final d = badge.earnedAt!;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '${t('SCREEN.BADGES.EARNED_AT', fallback: 'Obtenu le')} $day/$month/${d.year}';
  }
}

class _BadgeVisual extends StatelessWidget {
  const _BadgeVisual({required this.icon});

  final String icon;

  bool get _isRemote =>
      icon.startsWith('http://') || icon.startsWith('https://');

  bool get _looksLikeAssetPath {
    return icon.contains('/') &&
        (icon.endsWith('.png') ||
            icon.endsWith('.jpg') ||
            icon.endsWith('.jpeg') ||
            icon.endsWith('.webp') ||
            icon.endsWith('.gif'));
  }

  @override
  Widget build(BuildContext context) {
    if (_isRemote) {
      return Image.network(
        icon,
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Text('🏅', style: TextStyle(fontSize: 28)),
      );
    }

    if (_looksLikeAssetPath) {
      return Image.asset(
        icon,
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Text('🏅', style: TextStyle(fontSize: 28)),
      );
    }

    return Text(icon, style: const TextStyle(fontSize: 28));
  }
}
