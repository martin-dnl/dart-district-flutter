import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_version_models.dart';
import 'app_version_providers.dart';

class VersionGate extends ConsumerStatefulWidget {
  const VersionGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VersionGate> createState() => _VersionGateState();
}

class _VersionGateState extends ConsumerState<VersionGate> {
  AppVersionCheckResult? _result;
  bool _isLoading = true;
  bool _softDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runCheck();
    });
  }

  Future<void> _runCheck() async {
    try {
      final checker = ref.read(appVersionServiceProvider);
      final result = await checker.check();

      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });

      if (result.decision == AppVersionDecision.softUpdate &&
          !_softDialogShown) {
        _softDialogShown = true;
        await _showSoftUpdateDialog(result.policy);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    if (result?.decision == AppVersionDecision.forceUpdate) {
      return _ForceUpdateScreen(
        message: result!.policy.messageForceUpdate,
        storeUrl: _storeUrl(result.policy),
      );
    }

    if (_isLoading) {
      return Stack(children: [widget.child, const SizedBox.shrink()]);
    }

    return widget.child;
  }

  Future<void> _showSoftUpdateDialog(AppVersionPolicy policy) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mise a jour disponible'),
          content: Text(policy.messageSoftUpdate),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Plus tard'),
            ),
            FilledButton(
              onPressed: () async {
                await _openStore(_storeUrl(policy));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Mettre a jour'),
            ),
          ],
        );
      },
    );
  }

  String _storeUrl(AppVersionPolicy policy) {
    if (kIsWeb) {
      return '';
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return policy.storeUrlIos;
    }
    return policy.storeUrlAndroid;
  }

  Future<void> _openStore(String url) async {
    if (url.isEmpty) {
      return;
    }
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ForceUpdateScreen extends StatelessWidget {
  const _ForceUpdateScreen({required this.message, required this.storeUrl});

  final String message;
  final String storeUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update_alt_rounded, size: 72),
                const SizedBox(height: 20),
                const Text(
                  'Mise a jour obligatoire',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () async {
                    if (storeUrl.isEmpty) return;
                    await launchUrl(
                      Uri.parse(storeUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Mettre a jour maintenant'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
