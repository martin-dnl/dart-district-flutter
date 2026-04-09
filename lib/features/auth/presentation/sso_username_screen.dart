import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/translation_service.dart';
import '../../../core/network/api_providers.dart';
import '../controller/auth_controller.dart';

class SsoUsernameScreen extends ConsumerStatefulWidget {
  const SsoUsernameScreen({super.key});

  @override
  ConsumerState<SsoUsernameScreen> createState() => _SsoUsernameScreenState();
}

class _SsoUsernameScreenState extends ConsumerState<SsoUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _isLoadingLanguages = true;
  String _languageCode = 'fr-FR';
  List<LanguageOption> _languages = const <LanguageOption>[
    LanguageOption(
      code: 'fr-FR',
      countryName: 'France',
      languageName: 'Francais',
      flagEmoji: '🇫🇷',
      isDefault: true,
    ),
    LanguageOption(
      code: 'en-US',
      countryName: 'United States',
      languageName: 'English',
      flagEmoji: '🇺🇸',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLanguages() async {
    final service = TranslationService(ref.read(apiClientProvider));
    final preferred = await service.getPreferredLanguage();

    try {
      final languages = await service.getAvailableLanguages();
      if (!mounted) {
        return;
      }
      final hasPreferred = languages.any((entry) => entry.code == preferred);
      setState(() {
        _languages = languages;
        _languageCode = hasPreferred
            ? preferred
            : (languages.isNotEmpty ? languages.first.code : 'fr-FR');
        _isLoadingLanguages = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _languageCode = preferred;
        _isLoadingLanguages = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.patch<Map<String, dynamic>>(
        '/users/me',
        data: {
          'username': _usernameCtrl.text.trim(),
          'preferred_language': _languageCode,
        },
      );
      await ref.read(authControllerProvider.notifier).confirmUsernameSetup();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = t(
          'COMMON.ERROR_GENERIC',
          fallback: 'Ce pseudo est déjà utilisé ou invalide. Essayez-en un autre.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(
                      'SCREEN.AUTH.CHOOSE_USERNAME',
                      fallback: 'CHOISIR UN PSEUDO',
                    ),
                    style: GoogleFonts.rajdhani(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      'SCREEN.AUTH.USERNAME_HINT',
                      fallback: 'Votre pseudo sera visible par les autres joueurs.',
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 36),
                  TextFormField(
                    controller: _usernameCtrl,
                    autofocus: true,
                    maxLength: 30,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: t(
                        'SCREEN.AUTH.CHOOSE_USERNAME',
                        fallback: 'Pseudo',
                      ),
                      hintText: 'ex: DartMaster42',
                      filled: true,
                      fillColor: AppColors.surface,
                      counterStyle: const TextStyle(color: AppColors.textHint),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.stroke,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.error,
                          width: 1,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.error,
                          width: 2,
                        ),
                      ),
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      hintStyle: const TextStyle(color: AppColors.textHint),
                      errorStyle: const TextStyle(color: AppColors.error),
                    ),
                    validator: (v) {
                      final val = v?.trim() ?? '';
                      if (val.isEmpty) {
                        return t(
                          'COMMON.ERROR_GENERIC',
                          fallback: 'Le pseudo ne peut pas être vide.',
                        );
                      }
                      if (val.length < 3) {
                        return 'Minimum 3 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingLanguages)
                    const LinearProgressIndicator(minHeight: 2)
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _languageCode,
                      isExpanded: true,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: t(
                          'SCREEN.AUTH.CHOOSE_LANGUAGE',
                          fallback: 'Langue',
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.stroke,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        labelStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      dropdownColor: AppColors.surface,
                      items: _languages
                          .map(
                            (lang) => DropdownMenuItem<String>(
                              value: lang.code,
                              child: Text(lang.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _loading
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() => _languageCode = value);
                            },
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primaryDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                          : Text(
                              t('COMMON.CONFIRM', fallback: 'CONTINUER'),
                              style: GoogleFonts.rajdhani(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.background,
                              ),
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
}
