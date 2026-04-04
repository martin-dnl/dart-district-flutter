import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';

class ClubMapMarker extends StatelessWidget {
  const ClubMapMarker({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size(size - 4, size - 4),
          painter: _DartboardPainter(),
        ),
      ),
    );
  }
}

class _DartboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final outer = Paint()..color = AppColors.background;
    final ring = Paint()..color = AppColors.primary;
    final inner = Paint()..color = const Color(0xFFD9F505);
    final bull = Paint()..color = const Color(0xFFEF4444);

    canvas.drawCircle(center, radius, outer);
    canvas.drawCircle(center, radius * 0.82, ring);
    canvas.drawCircle(center, radius * 0.54, outer);
    canvas.drawCircle(center, radius * 0.30, inner);
    canvas.drawCircle(center, radius * 0.12, bull);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
