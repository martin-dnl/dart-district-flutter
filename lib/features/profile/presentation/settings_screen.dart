import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/config/dart_sense_service.dart' as mode;
import '../../../core/config/translation_service.dart';
import '../../../core/database/local_storage.dart';
import '../../../core/network/dart_sense_service.dart';
import '../../../core/network/api_providers.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../auth/controller/auth_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSigningOut = false;
  bool _isDeletingAccount = false;
  bool _isLoadingGameOptions = true;
  bool _isSavingGameOptions = false;
  bool _isLoadingLanguage = true;
  bool _isSavingLanguage = false;
  bool _isLoadingDartSense = true;
  bool _isSavingDartSense = false;
  bool _isRunningDartSense = false;
  static const String _scoreModeSettingKey = 'GAME_OPTION.SCORE_MODE';
  static const String _scoreModeBox = 'settings';
  static const String _scoreModeLocalKey = 'score_mode';
  static const String _scoreModePendingSyncKey = 'score_mode_pending_sync';
  static const String _manualScoreMode = 'MANUAL';
  static const String _dartboardScoreMode = 'DARTBOARD';
  static const String _tempoScoreMode = 'TEMPO';
  String _scoreMode = _manualScoreMode;
  List<LanguageOption> _languages = const <LanguageOption>[];
  String _languageCode = 'fr-FR';
  mode.DartSenseMode _dartSenseMode = mode.DartSenseMode.off;

  bool _isSupportedScoreMode(String value) {
    return value == _manualScoreMode ||
        value == _dartboardScoreMode ||
        value == _tempoScoreMode;
  }

  @override
  void initState() {
    super.initState();
    _loadGameOptions();
    _loadLanguageOptions();
    _loadDartSenseMode();
  }

  Future<void> _loadGameOptions() async {
    final local = await LocalStorage.get<String>(
      _scoreModeBox,
      _scoreModeLocalKey,
    );
    if (local != null && local.trim().isNotEmpty && mounted) {
      final localMode = local.trim().toUpperCase();
      setState(() {
        _scoreMode = _isSupportedScoreMode(localMode)
            ? localMode
            : _manualScoreMode;
      });
    }

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get<Map<String, dynamic>>(
        '/users/me/settings',
        queryParameters: {'key': _scoreModeSettingKey},
      );
      final raw = response.data ?? const <String, dynamic>{};
      final data = raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
      final value = (data['value'] ?? '').toString().trim();

      if (!mounted) {
        return;
      }
      final normalized = value.toUpperCase();
      setState(() {
        _scoreMode = _isSupportedScoreMode(normalized)
            ? normalized
            : _manualScoreMode;
        _isLoadingGameOptions = false;
      });
      await LocalStorage.put<String>(
        _scoreModeBox,
        _scoreModeLocalKey,
        _scoreMode,
      );
      await LocalStorage.remove(_scoreModeBox, _scoreModePendingSyncKey);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scoreMode = (local != null && local.trim().isNotEmpty)
            ? local.trim().toUpperCase()
            : _manualScoreMode;
        _isLoadingGameOptions = false;
      });
    }
  }

  Future<void> _saveScoreMode(String mode) async {
    final rawMode = mode.trim().toUpperCase();
    final nextMode = _isSupportedScoreMode(rawMode)
        ? rawMode
        : _manualScoreMode;
    final previous = _scoreMode;
    setState(() {
      _scoreMode = nextMode;
      _isSavingGameOptions = true;
    });
    await LocalStorage.put<String>(_scoreModeBox, _scoreModeLocalKey, nextMode);

    try {
      final api = ref.read(apiClientProvider);
      await api.patch<Map<String, dynamic>>(
        '/users/me/settings',
        data: {'key': _scoreModeSettingKey, 'value': nextMode},
      );
      await LocalStorage.remove(_scoreModeBox, _scoreModePendingSyncKey);
    } catch (_) {
      await LocalStorage.put<String>(
        _scoreModeBox,
        _scoreModePendingSyncKey,
        '1',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Options sauvegardees localement, synchronisation differee.',
            ),
          ),
        );
      }
      if (mounted && previous != nextMode) {
        setState(() => _scoreMode = nextMode);
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingGameOptions = false);
      }
    }
  }

  Future<void> _loadLanguageOptions() async {
    final service = TranslationService(ref.read(apiClientProvider));
    final localCode = await service.getPreferredLanguage();
    if (mounted) {
      setState(() => _languageCode = localCode);
    }

    try {
      final languages = await service.getAvailableLanguages();
      if (!mounted) {
        return;
      }

      final hasCurrent = languages.any((entry) => entry.code == _languageCode);
      setState(() {
        _languages = languages;
        _languageCode = hasCurrent
            ? _languageCode
            : (languages.isNotEmpty ? languages.first.code : 'fr-FR');
        _isLoadingLanguage = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _languages = const <LanguageOption>[
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
        _isLoadingLanguage = false;
      });
    }
  }

  Future<void> _saveLanguage(String languageCode) async {
    final code = languageCode.trim();
    if (code.isEmpty) {
      return;
    }

    final previous = _languageCode;
    setState(() {
      _languageCode = code;
      _isSavingLanguage = true;
    });

    try {
      final service = TranslationService(ref.read(apiClientProvider));
      await service.setPreferredLanguage(code);
      await ref.read(authControllerProvider.notifier).refreshCurrentUser();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('SCREEN.SETTINGS.LANGUAGE_UPDATED', fallback: 'Langue mise a jour.'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _languageCode = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'SCREEN.SETTINGS.LANGUAGE_UPDATE_FAILED',
              fallback: 'Impossible de mettre a jour la langue.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingLanguage = false);
      }
    }
  }

  Future<void> _loadDartSenseMode() async {
    final service = mode.DartSenseService(ref.read(apiClientProvider));
    final loadedMode = await service.loadMode();
    if (!mounted) {
      return;
    }
    setState(() {
      _dartSenseMode = loadedMode;
      _isLoadingDartSense = false;
    });
  }

  Future<void> _saveDartSenseMode(mode.DartSenseMode modeValue) async {
    setState(() {
      _dartSenseMode = modeValue;
      _isSavingDartSense = true;
    });

    final service = mode.DartSenseService(ref.read(apiClientProvider));
    await service.saveMode(modeValue);

    if (!mounted) {
      return;
    }

    setState(() => _isSavingDartSense = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            'SCREEN.SETTINGS.DART_SENSE_SAVED',
            fallback: 'Option Dart Sense enregistree.',
          ),
        ),
      ),
    );
  }

  Future<void> _runDartSenseTest() async {
    if (_dartSenseMode == mode.DartSenseMode.off || _isRunningDartSense) {
      if (_dartSenseMode == mode.DartSenseMode.off) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'SCREEN.SETTINGS.DART_SENSE_ENABLE_FIRST',
                fallback: 'Activez Dart Sense (ON) avant de lancer un test.',
              ),
            ),
          ),
        );
      }
      return;
    }

    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 1800,
    );
    if (photo == null || !mounted) {
      return;
    }

    setState(() => _isRunningDartSense = true);
    try {
      final service = DartSenseApiService(ref.read(apiClientProvider));
      final darts = await service.detect(File(photo.path));
      if (!mounted) {
        return;
      }

      if (darts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('SCREEN.SETTINGS.DART_SENSE_NO_DARTS', fallback: 'Aucune fleche detectee.'),
            ),
          ),
        );
        return;
      }

      final total = darts.fold<int>(0, (sum, dart) => sum + dart.score);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (dialogContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(photo.path),
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t('SCREEN.SETTINGS.DART_SENSE_RESULT', fallback: 'Resultat Dart Sense'),
                    style: Theme.of(dialogContext).textTheme.titleMedium
                        ?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < darts.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        'Flechette ${i + 1}: ${darts[i].label} (${darts[i].score}) - ${(darts[i].confidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Total: $total',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text(
                              t(
                                'SCREEN.SETTINGS.RETAKE_PHOTO',
                                fallback: 'Reprendre la photo',
                              ),
                            ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text(t('COMMON.CONFIRM', fallback: 'Confirmer')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'SCREEN.SETTINGS.DART_SENSE_FAILED',
              fallback: 'Echec de detection Dart Sense.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRunningDartSense = false);
      }
    }
  }

  Future<void> _confirmAndSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('SCREEN.SETTINGS.SIGN_OUT', fallback: 'Deconnexion')),
        content: Text(
          t(
            'SCREEN.SETTINGS.SIGN_OUT_CONFIRM',
            fallback: 'Voulez-vous vraiment vous deconnecter ?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t('COMMON.CANCEL', fallback: 'Annuler')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              t('SCREEN.SETTINGS.SIGN_OUT_ACTION', fallback: 'Se deconnecter'),
            ),
          ),
        ],
      ),
    );

    if (shouldSignOut != true || !mounted) {
      return;
    }

    setState(() => _isSigningOut = true);

    try {
      await ref.read(authControllerProvider.notifier).signOut();
      if (!mounted) {
        return;
      }
      context.go(AppRoutes.notLogged);
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  Future<void> _confirmAndDeleteAccount() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: t('SCREEN.SETTINGS.DELETE_ACCOUNT', fallback: 'Supprimer votre compte'),
      message: t(
        'SCREEN.SETTINGS.DELETE_ACCOUNT_CONFIRM',
        fallback:
            'Cette action est irreversible. Votre compte sera anonymise et vos amities supprimees.',
      ),
      confirmLabel: t('SCREEN.SETTINGS.DELETE_ACCOUNT_ACTION', fallback: 'Supprimer'),
      confirmColor: AppColors.error,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _isDeletingAccount = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.delete<Map<String, dynamic>>('/users/me');
      await ref.read(authControllerProvider.notifier).signOut();
      if (mounted) {
        context.go(AppRoutes.notLogged);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'SCREEN.SETTINGS.DELETE_ACCOUNT_FAILED',
                fallback: 'Impossible de supprimer le compte.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(currentUserProvider)?.isGuest ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t('SCREEN.SETTINGS.TITLE', fallback: 'Settings')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const SizedBox(height: 8),
              Text(
                t('SCREEN.SETTINGS.GAME_OPTIONS', fallback: 'Game options'),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              if (_isLoadingGameOptions)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _scoreMode,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: t('SCREEN.SETTINGS.SCORE_MODE', fallback: 'Score mode'),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: _manualScoreMode,
                      child: Text('MANUAL'),
                    ),
                    DropdownMenuItem(
                      value: _dartboardScoreMode,
                      child: Text('DARTBOARD'),
                    ),
                    DropdownMenuItem(
                      value: _tempoScoreMode,
                      child: Text('TEMPO'),
                    ),
                  ],
                  onChanged: _isSavingGameOptions
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          _saveScoreMode(value);
                        },
                ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.stroke),
              const SizedBox(height: 8),
              Text(
                t('SCREEN.SETTINGS.LANGUAGE', fallback: 'Language'),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              if (_isLoadingLanguage)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _languageCode,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: t(
                      'SCREEN.SETTINGS.APPLICATION_LANGUAGE',
                      fallback: 'Application language',
                    ),
                    border: OutlineInputBorder(),
                  ),
                  items: _languages
                      .map(
                        (lang) => DropdownMenuItem<String>(
                          value: lang.code,
                          child: Text(lang.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _isSavingLanguage
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          _saveLanguage(value);
                        },
                ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.stroke),
              const SizedBox(height: 8),
              Text(
                t('SCREEN.SETTINGS.DART_SENSE', fallback: 'Dart Sense'),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              if (_isLoadingDartSense)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else
                DropdownButtonFormField<mode.DartSenseMode>(
                  initialValue: _dartSenseMode,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: t(
                      'SCREEN.SETTINGS.COACH_ASSISTANT',
                      fallback: 'Coach assistant',
                    ),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: mode.DartSenseMode.off,
                      child: Text('OFF'),
                    ),
                    DropdownMenuItem(
                      value: mode.DartSenseMode.on,
                      child: Text('ON'),
                    ),
                  ],
                  onChanged: _isSavingDartSense
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          _saveDartSenseMode(value);
                        },
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isRunningDartSense ? null : _runDartSenseTest,
                icon: _isRunningDartSense
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt_outlined),
                label: Text(
                  _isRunningDartSense
                      ? t(
                          'SCREEN.SETTINGS.DART_SENSE_DETECTING',
                          fallback: 'Detection en cours...',
                        )
                      : t(
                          'SCREEN.SETTINGS.DART_SENSE_BETA',
                          fallback: 'Dart Sense (Beta)',
                        ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.stroke),
              const SizedBox(height: 8),
              Text(
                t('SCREEN.SETTINGS.ACCOUNT', fallback: 'Compte'),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.about),
                icon: const Icon(Icons.info_outline),
                label: Text(t('SCREEN.SETTINGS.ABOUT', fallback: 'A propos')),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _isSigningOut ? null : _confirmAndSignOut,
                icon: _isSigningOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                label: Text(
                  _isSigningOut
                      ? t('COMMON.LOADING', fallback: 'Deconnexion...')
                      : t('SCREEN.SETTINGS.SIGN_OUT', fallback: 'Deconnexion'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (!isGuest)
                ElevatedButton.icon(
                  onPressed: _isDeletingAccount
                      ? null
                      : _confirmAndDeleteAccount,
                  icon: const Icon(Icons.delete_forever),
                  label: Text(
                    _isDeletingAccount
                        ? t('COMMON.LOADING', fallback: 'Suppression...')
                        : t(
                            'SCREEN.SETTINGS.DELETE_ACCOUNT',
                            fallback: 'Supprimer mon compte',
                          ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              const Divider(color: AppColors.stroke),
            ],
          ),
        ),
      ),
    );
  }
}
