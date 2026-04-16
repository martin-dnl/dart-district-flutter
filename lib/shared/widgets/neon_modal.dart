import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/config/app_colors.dart';

Future<T?> showNeonDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      final builtChild = builder(dialogContext);
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: NeonModalContainer(child: _normalizeNeonChild(builtChild)),
      );
    },
  );
}

Widget _normalizeNeonChild(Widget child) {
  if (child is! AlertDialog) {
    return child;
  }

  return ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 460),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (child.title != null) child.title!,
          if (child.title != null && child.content != null)
            const SizedBox(height: 10),
          if (child.content != null) child.content!,
          if (child.actions != null && child.actions!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: OverflowBar(spacing: 8, children: child.actions!),
            ),
          ],
        ],
      ),
    ),
  );
}

class NeonModalContainer extends StatelessWidget {
  const NeonModalContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final glow = Color.lerp(AppColors.primary, AppColors.secondary, value)!;
        return CustomPaint(
          painter: _NeonModalPainter(progress: value),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: glow.withValues(alpha: 0.4),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: glow.withValues(alpha: 0.26),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _NeonModalPainter extends CustomPainter {
  const _NeonModalPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    final pulse = Color.lerp(AppColors.primary, AppColors.secondary, progress)!;

    final bloomPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.5),
        size.longestSide * 0.82,
        [pulse.withValues(alpha: 0.14), pulse.withValues(alpha: 0)],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);

    canvas.drawRRect(rrect.inflate(16), bloomPaint);
  }

  @override
  bool shouldRepaint(covariant _NeonModalPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
