import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;

import '../../../core/config/app_colors.dart';
import '../models/match_model.dart';

class MatchInvitationModal extends ConsumerStatefulWidget {
  const MatchInvitationModal({
    super.key,
    required this.invitation,
    required this.onAccept,
    required this.onRefuse,
  });

  final MatchModel invitation;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  @override
  ConsumerState<MatchInvitationModal> createState() =>
      _MatchInvitationModalState();
}

class _MatchInvitationModalState extends ConsumerState<MatchInvitationModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1900),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inviterName = widget.invitation.players[0].name;
    final gameMode = widget.invitation.mode;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: AppColors.pageGradient),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final glow = Color.lerp(
                  AppColors.primary,
                  AppColors.secondary,
                  _controller.value,
                )!;

                return CustomPaint(
                  painter: _NeonInvitePainter(
                    progress: _controller.value,
                    borderRadius: 20,
                  ),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: glow.withValues(alpha: 0.45),
                        width: 1.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: glow.withValues(alpha: 0.28),
                          blurRadius: 22,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sports_esports,
                          size: 60,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Invitation à une partie!',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$inviterName veut jouer au $gameMode avec toi!',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: widget.onRefuse,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text(
                                  'Refuser',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: widget.onAccept,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.background,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text(
                                  'Accepter',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NeonInvitePainter extends CustomPainter {
  const _NeonInvitePainter({
    required this.progress,
    required this.borderRadius,
  });

  final double progress;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final pulse = Color.lerp(AppColors.primary, AppColors.secondary, progress)!;
    final bloomPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height / 2),
        size.longestSide * 0.72,
        [pulse.withValues(alpha: 0.14), pulse.withValues(alpha: 0)],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36);

    canvas.drawRRect(rrect.inflate(20), bloomPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = LinearGradient(
        colors: [
          Color.lerp(AppColors.primary, AppColors.secondary, progress)!,
          Color.lerp(AppColors.secondary, AppColors.primary, progress)!,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);

    canvas.drawRRect(rrect.deflate(0.9), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _NeonInvitePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderRadius != borderRadius;
  }
}
