import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../shared/widgets/dart_button.dart';
import '../controller/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final showAppleButton = kIsWeb || defaultTargetPlatform != TargetPlatform.android;

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.status == AuthStatus.needsUsernameSetup) {
        context.go(
          AppRoutes.subscriptionStep1,
          extra: next.onboardingPayload ?? const <String, dynamic>{'isSso': true},
        );
        return;
      }

      if (next.status == AuthStatus.authenticated) {
        context.go(AppRoutes.home);
        return;
      }

      final hasNewError = next.error != null && next.error != prev?.error;
      if (hasNewError) {
        _showAuthFailureDialog(next.error!, next.debugDetails);
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => context.go(AppRoutes.notLogged),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.stroke),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text.rich(
                      TextSpan(
                        text: 'DARTS',
                        children: const [
                          TextSpan(
                            text: 'DISTRICT',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ],
                      ),
                      style: GoogleFonts.rajdhani(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'BON RETOUR',
                  style: GoogleFonts.rajdhani(
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Connectez-vous pour reprendre la conquete',
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                _AuthField(
                  label: 'Email',
                  hint: 'Entrez votre email',
                  icon: Icons.mail,
                  controller: _emailController,
                ),
                const SizedBox(height: 14),
                _AuthField(
                  label: 'Mot de passe',
                  hint: 'Votre mot de passe',
                  icon: Icons.lock,
                  controller: _passwordController,
                  obscureText: true,
                  trailing: Text(
                    'Mot de passe oublie ?',
                    style: GoogleFonts.manrope(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _AuthField(
                  label: 'Club Actif',
                  hint: 'Selectionnez le club pour cette session',
                  icon: Icons.qr_code_scanner,
                  optional: true,
                ),
                if (authState.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    authState.error!,
                    style: GoogleFonts.manrope(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.check, color: AppColors.background, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Se souvenir de moi',
                      style: GoogleFonts.manrope(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                      ),
                    isLoading: authState.status == AuthStatus.loading,
                    width: double.infinity,
                    backgroundColor: Colors.transparent,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Text(
                    'Si votre profil est incomplet, vous serez redirige vers l\'etape de configuration apres connexion.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () => context.go(AppRoutes.subscription),
                    child: Text(
                      'Pas encore de compte ? Inscription',
                      style: GoogleFonts.manrope(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OU CONTINUER AVEC',
                        style: GoogleFonts.manrope(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DartButton(
                        text: 'Google',
                        icon: Icons.g_mobiledata,
                        isOutlined: true,
                        onPressed: () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle(),
                      ),
                    ),
                    if (showAppleButton) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: DartButton(
                        .read(authControllerProvider.notifier)
                        .continueAsGuest(),
                    child: Text(
                      'Continuer en mode invite',
                      style: GoogleFonts.manrope(
                        color: AppColors.textHint,
                        fontWeight: FontWeight.w600,
                      ),
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

  void _showAuthFailureDialog(String message, String? details) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'Echec de connexion',
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (details != null && details.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Logs techniques',
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    details,
                    style: GoogleFonts.robotoMono(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (details != null && details.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: details));
                  if (!mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logs copies dans le presse-papiers.')),
                  );
                },
                child: Text(
                  'Copier logs',
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Fermer',
                style: GoogleFonts.manrope(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AuthField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController? controller;
  final bool obscureText;
  final Widget trailing;
  final bool optional;

  const _AuthField({
    required this.label,
    required this.hint,
    required this.icon,
    this.controller,
    this.obscureText = false,
    this.trailing = const SizedBox.shrink(),
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (optional)
              Text(
                'Optionnel',
                style: GoogleFonts.manrope(
                  color: AppColors.textHint,
                  fontSize: 12,
                ),
              ),
            trailing,
          ],
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.textHint, size: 18),
  }
}
