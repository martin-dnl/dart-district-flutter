import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/config/dart_sense_service.dart';
import '../../../core/config/translation_service.dart';
import '../../../core/database/local_storage.dart';
import '../../../core/network/api_providers.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../auth/controller/auth_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSigningOut = false;
  bool _isDeletingAccount = false;
  bool _isLoadingGameOptions = true;
  bool _isSavingGameOptions = false;
  bool _isLoadingLanguage = true;
  bool _isSavingLanguage = false;
  bool _isLoadingDartSense = true;
  bool _isSavingDartSense = false;
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
  DartSenseMode _dartSenseMode = DartSenseMode.off;

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
          LanguageOption(code: 'fr-FR', name: 'Francais', isDefault: true),
          LanguageOption(code: 'en-US', name: 'English'),
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
        const SnackBar(content: Text('Langue mise a jour.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _languageCode = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de mettre a jour la langue.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingLanguage = false);
      }
    }
  }

  Future<void> _loadDartSenseMode() async {
    final service = DartSenseService(ref.read(apiClientProvider));
    final mode = await service.loadMode();
    if (!mounted) {
      return;
    }
    setState(() {
      _dartSenseMode = mode;
      _isLoadingDartSense = false;
    });
  }

  Future<void> _saveDartSenseMode(DartSenseMode mode) async {
    setState(() {
      _dartSenseMode = mode;
      _isSavingDartSense = true;
    });

    final service = DartSenseService(ref.read(apiClientProvider));
    await service.saveMode(mode);

    if (!mounted) {
      return;
    }

    setState(() => _isSavingDartSense = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Option Dart Sense enregistree.')),
    );
  }

  Future<void> _confirmAndSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deconnexion'),
        content: const Text('Voulez-vous vraiment vous deconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Se deconnecter'),
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
      title: 'Supprimer votre compte',
      message:
          'Cette action est irreversible. Votre compte sera anonymise et vos amities supprimees.',
      confirmLabel: 'Supprimer',
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
          const SnackBar(content: Text('Impossible de supprimer le compte.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(currentUserProvider)?.isGuest ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Game options',
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
                  decoration: const InputDecoration(
                    labelText: 'Score mode',
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
              const Text(
                'Language',
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
                  decoration: const InputDecoration(
                    labelText: 'Application language',
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
              const Text(
                'Dart Sense',
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
                DropdownButtonFormField<DartSenseMode>(
                  initialValue: _dartSenseMode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Coach assistant',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: DartSenseMode.off,
                      child: Text('OFF'),
                    ),
                    DropdownMenuItem(
                      value: DartSenseMode.on,
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
              const SizedBox(height: 12),
              const Divider(color: AppColors.stroke),
              const SizedBox(height: 8),
              const Text(
                'Compte',
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
                label: const Text('A propos'),
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
                label: Text(_isSigningOut ? 'Deconnexion...' : 'Deconnexion'),
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
                        ? 'Suppression...'
                        : 'Supprimer mon compte',
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
