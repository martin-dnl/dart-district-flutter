import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/network/api_providers.dart';
import '../../club/models/club_model.dart';
import '../../contacts/models/contact_models.dart';

enum QrScanMode { user, club, tournament }

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key, required this.mode});

  final QrScanMode mode;

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isProcessing = false;
  bool _torchEnabled = false;

  static final RegExp _uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final raw = (barcode.rawValue ?? '').trim();
      if (raw.isEmpty) {
        continue;
      }
      if (!_uuidV4Pattern.hasMatch(raw)) {
        setState(() => _isProcessing = true);
        await _controller.stop();
        if (mounted) {
          context.pop();
        }
        continue;
      }

      setState(() => _isProcessing = true);
      await _controller.stop();

      try {
        final api = ref.read(apiClientProvider);

        if (widget.mode == QrScanMode.user) {
          final response = await api.get<Map<String, dynamic>>('/users/$raw');
          final data =
              response.data?['data'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
          final user = ContactModel.fromApi(data);
          if (!mounted) {
            return;
          }
          context.pop(user);
          return;
        }

        if (widget.mode == QrScanMode.club) {
          final response = await api.get<Map<String, dynamic>>('/clubs/$raw');
          final data =
              response.data?['data'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
          final club = ClubModel.fromApi(data);
          if (!mounted) {
            return;
          }
          context.pop(club);
          return;
        }

        final response = await api.get<Map<String, dynamic>>(
          '/tournaments/$raw',
        );
        final data =
            response.data?['data'] as Map<String, dynamic>? ??
            const <String, dynamic>{};
        if (!mounted) {
          return;
        }
        context.pop(data);
        return;
      } catch (_) {
        if (!mounted) {
          return;
        }
        if (widget.mode == QrScanMode.tournament) {
          context.pop(<String, dynamic>{'not_found': true, 'value': raw});
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.mode == QrScanMode.user
                  ? 'QR invalide: utilisateur introuvable.'
                  : widget.mode == QrScanMode.club
                  ? 'QR invalide: club introuvable.'
                  : 'QR invalide: tournoi introuvable.',
            ),
          ),
        );
        setState(() => _isProcessing = false);
        await _controller.start();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.mode) {
      QrScanMode.user => 'Scannez le QR code de votre adversaire',
      QrScanMode.club => 'Scannez le QR code du club',
      QrScanMode.tournament => 'Scannez le QR code du tournoi',
    };

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scanner QR'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          _QrMask(title: title),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surface.withValues(alpha: 0.9),
                  foregroundColor: AppColors.textPrimary,
                ),
                onPressed: () async {
                  await _controller.toggleTorch();
                  setState(() {
                    _torchEnabled = !_torchEnabled;
                  });
                },
                icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off),
                label: Text(_torchEnabled ? 'Torche active' : 'Activer torche'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrMask extends StatelessWidget {
  const _QrMask({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    const cutout = 260.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final left = (constraints.maxWidth - cutout) / 2;
        final top = (constraints.maxHeight - cutout) / 2;
        final right = left + cutout;
        final bottom = top + cutout;

        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: top,
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
            Positioned(
              left: 0,
              top: top,
              width: left,
              height: cutout,
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
            Positioned(
              left: right,
              top: top,
              right: 0,
              height: cutout,
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
            Positioned(
              left: 0,
              top: bottom,
              right: 0,
              bottom: 0,
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
            Positioned(
              left: left,
              top: top,
              width: cutout,
              height: cutout,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: top - 64,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
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
