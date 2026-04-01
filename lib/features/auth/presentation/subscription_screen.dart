import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../shared/widgets/dart_button.dart';
import '../controller/auth_controller.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _uppercaseRegex = RegExp(r'[A-Z]');
  static final RegExp _digitRegex = RegExp(r'[0-9]');

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _goNext() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    context.go(
      AppRoutes.subscriptionStep1,
      extra: {
        'username': _usernameCtrl.text.trim(),
        'email': _emailCtrl.text.trim().toLowerCase(),
        'password': _passwordCtrl.text,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final showAppleButton = kIsWeb || defaultTargetPlatform != TargetPlatform.android;

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go(AppRoutes.notLogged),
                        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'INSCRIPTION',
                        style: GoogleFonts.rajdhani(
                          fontWeight: FontWeight.w700,
                          fontSize: 30,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _field(
                    label: 'Pseudo',
                    controller: _usernameCtrl,
                    validator: (value) {
                      final v = (value ?? '').trim();
                      if (v.isEmpty) return 'Le pseudo est obligatoire';
                      if (v.length < 3) return 'Minimum 3 caracteres';
                      if (v.length > 24) return 'Maximum 24 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(
                    label: 'Email',
                    controller: _emailCtrl,
                    keyboard: TextInputType.emailAddress,
                    validator: (value) {
                      final v = (value ?? '').trim();
                      if (v.isEmpty) return 'L\'email est obligatoire';
                      if (!_emailRegex.hasMatch(v)) return 'Format email invalide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(
                    label: 'Mot de passe',
                    controller: _passwordCtrl,
                    obscure: _obscurePassword,
                    trailing: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                    validator: (value) {
                      final v = value ?? '';
                      if (v.isEmpty) return 'Le mot de passe est obligatoire';
                      if (v.length < 8) return 'Minimum 8 caracteres';
                      if (!_uppercaseRegex.hasMatch(v)) {
                        return 'Ajoute au moins une majuscule';
                      }
                      if (!_digitRegex.hasMatch(v)) {
                        return 'Ajoute au moins un chiffre';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Le mot de passe doit contenir 8 caracteres, 1 majuscule et 1 chiffre.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
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
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _goNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Continuer',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
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
                          onPressed: authState.status == AuthStatus.loading
                              ? null
                              : () => ref
                                    .read(authControllerProvider.notifier)
                                    .signInWithGoogle(),
                        ),
                      ),
                      if (showAppleButton) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: DartButton(
                            text: 'Apple',
                            icon: Icons.apple,
                            isOutlined: true,
                            onPressed: authState.status == AuthStatus.loading
                                ? null
                                : () => ref
                                      .read(authControllerProvider.notifier)
                                      .signInWithApple(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
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

  Widget _field({
    required String label,
    required TextEditingController controller,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    String? Function(String?)? validator,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          validator: validator,
          decoration: InputDecoration(
            hintText: label,
            suffixIcon: trailing,
          ),
        ),
      ],
    );
  }
}
