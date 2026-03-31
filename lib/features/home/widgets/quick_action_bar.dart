import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';

class QuickActionBar extends StatelessWidget {
  const QuickActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _QuickAction(
            icon: Icons.play_arrow_rounded,
            label: 'Jouer',
            color: AppColors.primary,
            onTap: () => context.go(AppRoutes.play),
          ),
          const SizedBox(width: 12),
          _QuickAction(
            icon: Icons.qr_code_scanner,
            label: 'Scanner',
            color: AppColors.secondary,
            onTap: () {
              // TODO: Open QR scanner
            },
          ),
          const SizedBox(width: 12),
          _QuickAction(
            icon: Icons.leaderboard_outlined,
            label: 'Classement',
            color: AppColors.accent,
            onTap: () => context.go(AppRoutes.map),
          ),
          const SizedBox(width: 12),
          _QuickAction(
            icon: Icons.emoji_events_outlined,
            label: 'Tournois',
            color: AppColors.success,
            onTap: () {
              // TODO: Open tournaments
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
