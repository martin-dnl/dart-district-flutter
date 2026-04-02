import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';

class SubscriptionStep3Screen extends StatelessWidget {
  const SubscriptionStep3Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'BIENVENUE',
                      style: GoogleFonts.rajdhani(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.home),
                      child: const Text('Passer'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _RuleCard(
                  icon: Icons.sports_bar,
                  title: 'Jouer en presentiel',
                  text:
                      'Dart District est concu pour jouer en presentiel. Rencontrez des fans de flechettes autour d\'une cible et d\'une biere !',
                ),
                const SizedBox(height: 12),
                const _RuleCard(
                  icon: Icons.sports_esports,
                  title: 'Modes de jeu',
                  text:
                      'Jouez au 301, 501, Cricket et plus encore avec vos amis ou vos rivaux.',
                ),
                const SizedBox(height: 12),
                const _RuleCard(
                  icon: Icons.groups,
                  title: 'Clubs et tournois',
                  text:
                      'Inscrivez-vous dans le club le plus proche et defendez votre titre contre d\'autres clubs en participant a des tournois.',
                ),
                const SizedBox(height: 12),
                const _RuleCard(
                  icon: Icons.qr_code_scanner,
                  title: 'Batailles de territoire',
                  text:
                      'Flashez le QR code pres des cibles dans les clubs pour lancer une bataille de territoire !',
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go(AppRoutes.home),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'C\'est parti !',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    height: 1.4,
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
