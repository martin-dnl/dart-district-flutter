import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../controller/auth_controller.dart';

class SubscriptionStep2Screen extends ConsumerStatefulWidget {
  const SubscriptionStep2Screen({
    super.key,
    required this.payload,
  });

  final Map<String, dynamic> payload;

  @override
  ConsumerState<SubscriptionStep2Screen> createState() =>
      _SubscriptionStep2ScreenState();
}

class _SubscriptionStep2ScreenState extends ConsumerState<SubscriptionStep2Screen> {
  bool _acceptedRules = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go(AppRoutes.subscriptionStep3);
      }
    });

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
                    IconButton(
                      onPressed: () => context.go(
                        AppRoutes.subscriptionStep1,
                        extra: widget.payload,
                      ),
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CONDITIONS',
                      style: GoogleFonts.rajdhani(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go(
                        AppRoutes.subscriptionStep1,
                        extra: widget.payload,
                      ),
                      child: const Text('Refuser'),
                    ),
                  ],
                ),
                Text(
                  'Etape 2/2',
                  style: GoogleFonts.manrope(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: 1,
                  backgroundColor: AppColors.stroke,
                  color: AppColors.secondary,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            'Conditions d\'utilisation',
                            style: GoogleFonts.rajdhani(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _RuleCard(
                          icon: Icons.photo_camera_outlined,
                          title: 'Utilisation de vos donnees',
                          text:
                              'L\'application enregistre les photos de profil et messages que vous partagez afin de fournir les fonctionnalites sociales du service.',
                        ),
                        const SizedBox(height: 12),
                        const _RuleCard(
                          icon: Icons.gavel,
                          title: 'Contenus inappropries',
                          text:
                              'La diffusion de messages haineux, discriminatoires ou d\'images a caractere inapproprie est strictement interdite.',
                        ),
                        const SizedBox(height: 12),
                        const _RuleCard(
                          icon: Icons.shield_outlined,
                          title: 'Moderation et sanctions',
                          text:
                              'Le non-respect de ces regles entrainera une moderation pouvant aller jusqu\'au bannissement du compte, voire au blocage de la signature physique de l\'appareil.',
                          warning: true,
                        ),
                        const SizedBox(height: 12),
                        const _RuleCard(
                          icon: Icons.emoji_events_outlined,
                          title: 'Engagement en tournoi',
                          text:
                              'S\'inscrire a un tournoi implique de jouer sur place. En cas d\'absence, un malus est applique pouvant interdire temporairement ou definitivement l\'inscription aux tournois. Et en plus, c\'est la honte.',
                          warning: true,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _acceptedRules,
                              onChanged: (value) =>
                                  setState(() => _acceptedRules = value ?? false),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  'J\'ai lu et j\'accepte les conditions d\'utilisation.',
                                  style: GoogleFonts.manrope(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (authState.error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              authState.error!,
                              style: GoogleFonts.manrope(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                !_acceptedRules || authState.status == AuthStatus.loading
                                ? null
                                : () {
                                    final isSso = widget.payload['isSso'] == true;
                                    if (isSso) {
                                      ref
                                          .read(authControllerProvider.notifier)
                                          .completeSsoOnboarding(
                                            username: (widget.payload['username'] ?? '')
                                                .toString(),
                                            level: (widget.payload['level'] ?? '')
                                                .toString(),
                                            preferredHand:
                                                (widget.payload['preferredHand'] ?? '')
                                                    .toString(),
                                          );
                                      return;
                                    }

                                    ref.read(authControllerProvider.notifier).signUpWithEmail(
                                          username:
                                              (widget.payload['username'] ?? '').toString(),
                                          email:
                                              (widget.payload['email'] ?? '').toString(),
                                          password:
                                              (widget.payload['password'] ?? '').toString(),
                                          level: (widget.payload['level'] ?? '').toString(),
                                          preferredHand:
                                              (widget.payload['preferredHand'] ?? '')
                                                  .toString(),
                                        );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.background,
                              disabledBackgroundColor: AppColors.surface,
                              disabledForegroundColor: AppColors.textHint,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              authState.status == AuthStatus.loading
                                  ? 'Creation du compte...'
                                  : 'Commencer',
                              style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
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
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? Colors.amber : AppColors.secondary;

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
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    color: warning ? Colors.amber : AppColors.textPrimary,
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
