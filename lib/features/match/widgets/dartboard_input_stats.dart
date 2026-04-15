import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../../../shared/models/dartboard_heatmap_models.dart';

const Color _heatLowColor = AppColors.info;
const Color _heatMidLowColor = Color(0xFFF59A4A);
const Color _heatMidHighColor = Color(0xFFFF8C00);
const Color _heatHighColor = AppColors.error;

class DartboardInputStats extends StatelessWidget {
  const DartboardInputStats({
    super.key,
    required this.hits,
    this.title,
    this.subtitle,
    this.emptyMessage = 'Aucune flechette avec position pour cette selection.',
    this.padding = const EdgeInsets.all(14),
    this.showLegend = true,
  });

  final List<DartboardHeatHit> hits;
  final String? title;
  final String? subtitle;
  final String emptyMessage;
  final EdgeInsetsGeometry padding;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final filteredHits = hits.where((hit) => hit.hasValidPosition).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stroke),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                color: Colors.transparent,
                child: filteredHits.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Text(
                            emptyMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    : CustomPaint(
                        painter: _DartboardHeatmapPainter(hits: filteredHits),
                      ),
              ),
            ),
          ),
          if (showLegend && filteredHits.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _HeatLegend(),
          ],
        ],
      ),
    );
  }
}

class _HeatLegend extends StatelessWidget {
  const _HeatLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Faible',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [
                  _heatLowColor,
                  _heatMidLowColor,
                  _heatMidHighColor,
                  _heatHighColor,
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Forte',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DartboardHeatmapPainter extends CustomPainter {
  const _DartboardHeatmapPainter({required this.hits});

  final List<DartboardHeatHit> hits;

  static const List<int> _sectorOrder = <int>[
    20,
    1,
    18,
    4,
    13,
    6,
    10,
    15,
    2,
    17,
    3,
    19,
    7,
    16,
    8,
    11,
    14,
    9,
    12,
    5,
  ];

  static const double _playableRatio = 0.82;
  static const double _rInnerBull = 6.35 / 170.0;
  static const double _rOuterBull = 15.9 / 170.0;
  static const double _rTripleInner = 99.0 / 170.0;
  static const double _rTripleOuter = 107.0 / 170.0;
  static const double _rDoubleInner = 162.0 / 170.0;

  static const Color _boardOuterBlack = Color(0xFF050505);
  static const Color _blackSegment = Color(0xFF020202);
  static const Color _beigeSegment = Color(0xFFD9CFB0);
  static const Color _ringRed = Color(0xFFE96A73);
  static const Color _ringGreen = Color(0xFF5EC796);
  static const Color _wireWhite = Color(0xFFECECEC);

  @override
  void paint(Canvas canvas, Size size) {
    final squareSide = math.min(size.width, size.height) * 0.98;
    final boardRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: squareSide,
      height: squareSide,
    );
    final center = boardRect.center;
    final outerRadius = boardRect.width / 2;
    final playableRadius = outerRadius * _playableRatio;

    _drawBoard(canvas, center, outerRadius, playableRadius);
    _drawHeat(canvas, boardRect, playableRadius);
    _drawNumbers(canvas, center, playableRadius, outerRadius);
  }

  void _drawBoard(
    Canvas canvas,
    Offset center,
    double outerRadius,
    double playableRadius,
  ) {
    const sectorSweep = 2 * math.pi / 20;
    final wirePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _wireWhite;

    canvas.drawCircle(center, outerRadius, Paint()..color = _boardOuterBlack);
    canvas.drawCircle(center, playableRadius, Paint()..color = _blackSegment);

    for (var i = 0; i < 20; i++) {
      final start = -math.pi / 2 + i * sectorSweep - (sectorSweep / 2);
      _drawSectorRing(
        canvas: canvas,
        center: center,
        start: start,
        sweep: sectorSweep,
        playableRadius: playableRadius,
        innerRatio: _rOuterBull,
        outerRatio: _rTripleInner,
        fill: i.isEven ? _beigeSegment : _blackSegment,
      );
      _drawSectorRing(
        canvas: canvas,
        center: center,
        start: start,
        sweep: sectorSweep,
        playableRadius: playableRadius,
        innerRatio: _rTripleInner,
        outerRatio: _rTripleOuter,
        fill: i.isEven ? _ringGreen : _ringRed,
      );
      _drawSectorRing(
        canvas: canvas,
        center: center,
        start: start,
        sweep: sectorSweep,
        playableRadius: playableRadius,
        innerRatio: _rTripleOuter,
        outerRatio: _rDoubleInner,
        fill: i.isEven ? _blackSegment : _beigeSegment,
      );
      _drawSectorRing(
        canvas: canvas,
        center: center,
        start: start,
        sweep: sectorSweep,
        playableRadius: playableRadius,
        innerRatio: _rDoubleInner,
        outerRatio: 1.0,
        fill: i.isEven ? _ringRed : _ringGreen,
      );
    }

    canvas.drawCircle(center, playableRadius, wirePaint);
    canvas.drawCircle(center, playableRadius * _rDoubleInner, wirePaint);
    canvas.drawCircle(center, playableRadius * _rTripleOuter, wirePaint);
    canvas.drawCircle(center, playableRadius * _rTripleInner, wirePaint);
    canvas.drawCircle(center, playableRadius * _rOuterBull, wirePaint);
    canvas.drawCircle(
      center,
      playableRadius * _rOuterBull,
      Paint()..color = _ringGreen,
    );
    canvas.drawCircle(
      center,
      playableRadius * _rInnerBull,
      Paint()..color = _ringRed,
    );
    canvas.drawCircle(center, playableRadius * _rOuterBull, wirePaint);
    canvas.drawCircle(center, playableRadius * _rInnerBull, wirePaint);
  }

  void _drawSectorRing({
    required Canvas canvas,
    required Offset center,
    required double start,
    required double sweep,
    required double playableRadius,
    required double innerRatio,
    required double outerRatio,
    required Color fill,
  }) {
    final inner = playableRadius * innerRatio;
    final outer = playableRadius * outerRatio;

    final path = Path()
      ..moveTo(
        center.dx + inner * math.cos(start),
        center.dy + inner * math.sin(start),
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: outer),
        start,
        sweep,
        false,
      )
      ..lineTo(
        center.dx + inner * math.cos(start + sweep),
        center.dy + inner * math.sin(start + sweep),
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: inner),
        start + sweep,
        -sweep,
        false,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = _wireWhite,
    );
  }

  void _drawHeat(Canvas canvas, Rect boardRect, double playableRadius) {
    final points = hits
        .map(
          (hit) => Offset(
            boardRect.left + (hit.x * boardRect.width),
            boardRect.top + (hit.y * boardRect.height),
          ),
        )
        .toList(growable: false);

    if (points.isEmpty) {
      return;
    }

    final kernelRadius = playableRadius * 0.16;
    final densities = points
        .map((point) {
          var density = 0.0;
          for (final other in points) {
            final distance = (point - other).distance;
            final normalized = (distance / (kernelRadius * 1.2)).clamp(
              0.0,
              1.0,
            );
            density += 1 - normalized;
          }
          return density;
        })
        .toList(growable: false);

    final maxDensity = densities.fold<double>(0, math.max);
    final clip = Path()
      ..addOval(
        Rect.fromCircle(center: boardRect.center, radius: playableRadius),
      );

    canvas.save();
    canvas.clipPath(clip);

    for (var i = 0; i < points.length; i++) {
      final intensity = maxDensity <= 0
          ? 0.35
          : (densities[i] / maxDensity).clamp(0.16, 1.0);
      final heatColor = _heatColor(intensity);
      final shader = ui.Gradient.radial(
        points[i],
        kernelRadius,
        [
          heatColor.withValues(alpha: 0.85),
          heatColor.withValues(alpha: 0.45),
          heatColor.withValues(alpha: 0.0),
        ],
        const [0.0, 0.42, 1.0],
      );

      canvas.drawCircle(
        points[i],
        kernelRadius,
        Paint()
          ..shader = shader
          ..blendMode = BlendMode.srcOver,
      );
    }

    for (final point in points) {
      canvas.drawCircle(
        point,
        boardRect.width * 0.0055,
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
    }

    canvas.restore();
  }

  Color _heatColor(double t) {
    if (t < 0.34) {
      return Color.lerp(_heatLowColor, _heatMidLowColor, t / 0.34) ??
          _heatMidLowColor;
    }
    if (t < 0.68) {
      return Color.lerp(
            _heatMidLowColor,
            _heatMidHighColor,
            (t - 0.34) / 0.34,
          ) ??
          _heatMidHighColor;
    }
    return Color.lerp(_heatMidHighColor, _heatHighColor, (t - 0.68) / 0.32) ??
        _heatHighColor;
  }

  void _drawNumbers(
    Canvas canvas,
    Offset center,
    double playableRadius,
    double outerRadius,
  ) {
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    const sectorSweep = 2 * math.pi / 20;
    final numberRadius =
        playableRadius + ((outerRadius - playableRadius) * 0.56);

    for (var i = 0; i < 20; i++) {
      final angle = -math.pi / 2 + i * sectorSweep;
      final pos = Offset(
        center.dx + numberRadius * math.cos(angle),
        center.dy + numberRadius * math.sin(angle),
      );

      tp.text = TextSpan(
        text: '${_sectorOrder[i]}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      );
      tp.layout();

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _DartboardHeatmapPainter oldDelegate) {
    return oldDelegate.hits.length != hits.length || oldDelegate.hits != hits;
  }
}
