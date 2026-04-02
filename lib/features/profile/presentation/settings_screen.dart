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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _isDeletingAccount ? null : _confirmAndDeleteAccount,
                icon: const Icon(Icons.delete_forever),
                label: Text(
                  _isDeletingAccount
                      ? 'Suppression...'
                      : 'Supprimer mon compte',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
