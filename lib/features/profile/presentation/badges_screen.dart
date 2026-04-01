import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../controller/profile_controller.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(profileControllerProvider).badges;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mes Badges'),
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
                  Text(badge.icon, style: const TextStyle(fontSize: 28)),
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
      return 'Non obtenu';
    }

    final d = badge.earnedAt!;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return 'Obtenu le $day/$month/${d.year}';
  }
}
