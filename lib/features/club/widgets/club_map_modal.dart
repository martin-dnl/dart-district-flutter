import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';

class ClubMapModal {
  const ClubMapModal._();

  static Future<void> show(
    BuildContext context, {
    required String clubId,
    required String name,
    required String address,
    String? city,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewPadding.bottom + 14 + 100,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Text(
                name,
                textAlign: TextAlign.center,
                style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                address,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if ((city ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    city!,
                    style: GoogleFonts.manrope(
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.push('/club/$clubId');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                  ),
                  child: Text(
                    'Voir plus',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
