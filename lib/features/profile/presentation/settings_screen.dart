import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
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
  static const String _scoreModeSettingKey = 'GAME_OPTION.SCORE_MODE';
  static const String _manualScoreMode = 'MANUAL';
  static const String _dartboardScoreMode = 'DARTBOARD';
  String _scoreMode = _manualScoreMode;

  @override
  void initState() {
    super.initState();
    _loadGameOptions();
  }

  Future<void> _loadGameOptions() async {
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
      setState(() {
        _scoreMode = value.isEmpty ? _manualScoreMode : value;
        _isLoadingGameOptions = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scoreMode = _manualScoreMode;
        _isLoadingGameOptions = false;
      });
    }
  }

  Future<void> _saveScoreMode(String mode) async {
    final nextMode = mode.trim().isEmpty ? _manualScoreMode : mode.trim();
    final previous = _scoreMode;
    setState(() {
      _scoreMode = nextMode;
      _isSavingGameOptions = true;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.patch<Map<String, dynamic>>(
        '/users/me/settings',
        data: {'key': _scoreModeSettingKey, 'value': nextMode},
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _scoreMode = previous;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de sauvegarder les options de jeu.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingGameOptions = false);
      }
    }
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
