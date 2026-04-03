import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../controller/auth_controller.dart';

class SubscriptionStep1Screen extends ConsumerStatefulWidget {
  const SubscriptionStep1Screen({
    super.key,
    required this.payload,
  });

  final Map<String, dynamic> payload;

  @override
  ConsumerState<SubscriptionStep1Screen> createState() => _SubscriptionStep1ScreenState();
}

class _SubscriptionStep1ScreenState extends ConsumerState<SubscriptionStep1Screen> {
  late final TextEditingController _usernameCtrl;
  final _formKey = GlobalKey<FormState>();
  double _levelIndex = 1;
  String _handedness = 'right';
  final Set<String> _slots = {'Soiree'};

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(
      text: (widget.payload['username'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = _levelIndex < 0.5
        ? 'debutant'
        : _levelIndex < 1.5
            ? 'intermediate'
            : 'pro';

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
                        onPressed: () => context.go(AppRoutes.subscription),
                        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CONFIGURATION',
                        style: GoogleFonts.rajdhani(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          if (!(_formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          context.go(
                            AppRoutes.subscriptionStep2,
                            extra: _buildPayload(level),
                          );
                        },
                        child: const Text('Passer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Etape 1/2',
                    style: GoogleFonts.manrope(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 0.5,
                    backgroundColor: AppColors.stroke,
                    color: AppColors.primary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 26),
                  Center(
                    child: Text(
                      'Votre profil',
                      style: GoogleFonts.rajdhani(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _usernameCtrl,
                    validator: (value) {
                      final v = (value ?? '').trim();
                      if (v.isEmpty) return 'Le pseudo est obligatoire';
                      if (v.length < 3) return 'Minimum 3 caracteres';
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Pseudo de joueur',
                      hintText: 'Ex: Bullseye_Killer',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Niveau estime',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Slider(
                    min: 0,
                    max: 2,
                    divisions: 2,
                    value: _levelIndex,
                    onChanged: (value) => setState(() => _levelIndex = value),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _levelLabel('Debutant', _levelIndex == 0),
                      _levelLabel('Intermediaire', _levelIndex == 1),
                      _levelLabel('Pro', _levelIndex == 2),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Main forte',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _chip(
                          label: 'Droitier',
                          selected: _handedness == 'right',
                          onTap: () => setState(() => _handedness = 'right'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _chip(
                          label: 'Gaucher',
                          selected: _handedness == 'left',
                          onTap: () => setState(() => _handedness = 'left'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Disponibilites principales',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _slotChip('Soiree'),
                      _slotChip('Week-end'),
                      _slotChip('Apres-midi'),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!(_formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        context.go(
                          AppRoutes.subscriptionStep2,
                          extra: _buildPayload(level),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Suivant',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.stroke,
          ),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surface,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _slotChip(String label) {
    final selected = _slots.contains(label);
    return InkWell(
      onTap: () {
        setState(() {
          if (selected) {
            _slots.remove(label);
          } else {
            _slots.add(label);
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.stroke,
          ),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surface,
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _levelLabel(String text, bool selected) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        color: selected ? AppColors.primary : AppColors.textHint,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }

  /// Builds the payload passed to step 2.
  /// Always re-stamps isSso from the live auth state so the flag survives
  /// even when the router redirects to this screen without an `extra` payload.
  Map<String, dynamic> _buildPayload(String level) {
    final authState = ref.read(authControllerProvider);
    final isSsoFromState = authState.status == AuthStatus.needsUsernameSetup ||
        (authState.onboardingPayload?['isSso'] == true);
    final isSsoFromPayload = widget.payload['isSso'] == true;

    return {
      ...widget.payload,
      if (isSsoFromState || isSsoFromPayload) 'isSso': true,
      'username': _usernameCtrl.text.trim(),
      'level': level,
      'preferredHand': _handedness,
      'availability': _slots.toList(),
    };
  }
}
