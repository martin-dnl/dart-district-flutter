import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';

class DartboardVisit {
  const DartboardVisit({
    required this.darts,
    required this.total,
    required this.doubleAttempts,
  });

  final List<int> darts;
  final int total;
  final int doubleAttempts;
}

enum _HitRing { singleInner, triple, singleOuter, double, outerBull, innerBull }

class _HitResult {
  const _HitResult({
    required this.score,
    required this.label,
    required this.ring,
    this.sectorNumber,
  });

  final int score;
  final String label;
  final _HitRing ring;
  final int? sectorNumber;
}

class DartboardInput extends StatefulWidget {
  const DartboardInput({
    super.key,
    required this.maxScore,
    required this.onSubmitVisit,
    this.fillAvailableHeight = false,
  });

  final int maxScore;
  final ValueChanged<DartboardVisit> onSubmitVisit;
  final bool fillAvailableHeight;

  @override
  State<DartboardInput> createState() => _DartboardInputState();
}

class _DartboardInputState extends State<DartboardInput> {
  final List<int> _darts = <int>[];
  bool _isAiming = false;
  Offset? _aimPoint;
  _HitResult? _previewHit;
  double _zoomScale = 1.55;

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

  int get _total => _darts.fold<int>(0, (sum, value) => sum + value);
  bool get _canSubmit => _darts.length == 3;

  String get _statusText {
    if (!_isAiming) {
      return 'Appui long sur la cible pour viser';
    }
    if (_previewHit == null) {
      return 'Relachez hors cible pour annuler';
    }
    return 'Zone: ${_previewHit!.label}';
  }

  void _addScore(int score) {
    if (_darts.length >= 3) {
      return;
    }
    setState(() {
      _darts.add(score);
    });
  }

  void _addMiss() {
    if (_darts.length >= 3) {
      return;
    }
    setState(() {
      _darts.add(0);
    });
  }

  void _undoLastDart() {
    if (_darts.isEmpty) {
      return;
    }
    setState(() {
      _darts.removeLast();
    });
  }

  void _submitVisit() {
    if (!_canSubmit) {
      return;
    }

    final boundedTotal = _total.clamp(0, 180);
    final boundedForRemaining = boundedTotal > widget.maxScore
        ? widget.maxScore
        : boundedTotal;

    widget.onSubmitVisit(
      DartboardVisit(
        darts: List<int>.from(_darts),
        total: boundedForRemaining,
        // In this mode, a visit is always 3 darts.
        doubleAttempts: 3,
      ),
    );

    setState(() {
      _darts.clear();
    });
  }

  void _onLongPressStart(LongPressStartDetails details, double size) {
    if (_darts.length >= 3) {
      return;
    }
    setState(() {
      _isAiming = true;
    });
    _updateAim(details.localPosition, size);
  }

  void _onLongPressMove(LongPressMoveUpdateDetails details, double size) {
    if (!_isAiming) {
      return;
    }
    _updateAim(details.localPosition, size);
  }

  void _onLongPressEnd(LongPressEndDetails _, double size) {
    if (!_isAiming) {
      return;
    }

    final hit = _previewHit;
    if (hit != null) {
      _addScore(hit.score);
    }

    setState(() {
      _isAiming = false;
      _aimPoint = null;
      _previewHit = null;
      _zoomScale = 1.55;
    });
  }

  void _updateAim(Offset localPosition, double size) {
    final center = Offset(size / 2, size / 2);
    final radius = size / 2;
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final normalizedR = distance / radius;

    _HitResult? hit;
    if (normalizedR <= 1.0) {
      hit = _scoreFromPolar(dx, dy, normalizedR);
    }

    final nearEdgeFactor = normalizedR.clamp(0.0, 1.0);
    final nextZoom = 1.7 - (nearEdgeFactor * 0.45);

    setState(() {
      _aimPoint = localPosition;
      _previewHit = hit;
      _zoomScale = nextZoom;
    });
  }

  _HitResult _scoreFromPolar(double dx, double dy, double normalizedR) {
    if (normalizedR <= 0.06) {
      return const _HitResult(
        score: 50,
        label: 'DBULL 50',
        ring: _HitRing.innerBull,
      );
    }
    if (normalizedR <= 0.12) {
      return const _HitResult(
        score: 25,
        label: 'SBULL 25',
        ring: _HitRing.outerBull,
      );
    }

    final angle = (math.atan2(dx, -dy) + (2 * math.pi)) % (2 * math.pi);
    final sectorWidth = 2 * math.pi / 20;
    final sectorIndex = ((angle + sectorWidth / 2) / sectorWidth).floor() % 20;
    final number = _sectorOrder[sectorIndex];

    _HitRing ring;
    int multiplier;

    if (normalizedR <= 0.50) {
      ring = _HitRing.singleInner;
      multiplier = 1;
    } else if (normalizedR <= 0.60) {
      ring = _HitRing.triple;
      multiplier = 3;
    } else if (normalizedR <= 0.87) {
      ring = _HitRing.singleOuter;
      multiplier = 1;
    } else {
      ring = _HitRing.double;
      multiplier = 2;
    }

    final score = number * multiplier;
    final prefix = switch (multiplier) {
      2 => 'D',
      3 => 'T',
      _ => 'S',
    };
    return _HitResult(
      score: score,
      label: '$prefix$number = $score',
      ring: ring,
      sectorNumber: number,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceLight, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: widget.fillAvailableHeight
            ? MainAxisSize.max
            : MainAxisSize.min,
        mainAxisAlignment: widget.fillAvailableHeight
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          _buildVisitSummary(),
          const SizedBox(height: 10),
          _buildStatusBar(),
          const SizedBox(height: 8),
          _buildInteractiveBoard(),
          const SizedBox(height: 8),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildVisitSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Darts: ${_darts.length}/3',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: List<Widget>.generate(3, (index) {
              final hasValue = index < _darts.length;
              return Expanded(
                child: Container(
                  height: 42,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
                  decoration: BoxDecoration(
                    color: hasValue
                        ? AppColors.primary.withValues(alpha: 0.14)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasValue ? AppColors.primary : AppColors.stroke,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    hasValue ? '${_darts[index]}' : '-',
                    style: TextStyle(
                      color: hasValue
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total visite: $_total',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_total > widget.maxScore)
                const Text(
                  'Bust potentiel',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Text(
        _statusText,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInteractiveBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final size = maxWidth.clamp(220.0, 360.0);
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: GestureDetector(
              onLongPressStart: (details) => _onLongPressStart(details, size),
              onLongPressMoveUpdate: (details) =>
                  _onLongPressMove(details, size),
              onLongPressEnd: (details) => _onLongPressEnd(details, size),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(size / 2),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedScale(
                        scale: _isAiming ? _zoomScale : 1.0,
                        duration: const Duration(milliseconds: 90),
                        curve: Curves.easeOut,
                        child: CustomPaint(
                          painter: _DartboardPainter(previewHit: _previewHit),
                        ),
                      ),
                      if (_isAiming && _aimPoint != null)
                        Positioned(
                          left: _aimPoint!.dx - 12,
                          top: _aimPoint!.dy - 12,
                          child: IgnorePointer(
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_isAiming && _aimPoint != null && _previewHit != null)
                        Positioned(
                          left: (_aimPoint!.dx - 44).clamp(0.0, size - 88),
                          top: (_aimPoint!.dy - 46).clamp(0.0, size - 24),
                          child: IgnorePointer(
                            child: Container(
                              width: 88,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.background.withValues(
                                  alpha: 0.88,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary),
                              ),
                              child: Text(
                                _previewHit!.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _darts.isEmpty ? null : _undoLastDart,
            icon: const Icon(Icons.undo),
            label: const Text('Retour'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _darts.length >= 3 ? null : _addMiss,
            icon: const Icon(Icons.radio_button_unchecked),
            label: const Text('Miss (0)'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: _canSubmit ? _submitVisit : null,
            icon: const Icon(Icons.check),
            label: const Text('Valider'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
            ),
          ),
        ),
      ],
    );
  }
}

class _DartboardPainter extends CustomPainter {
  const _DartboardPainter({required this.previewHit});

  final _HitResult? previewHit;

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

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringBounds = <(double, double, _HitRing?)>[
      (0.12, 0.50, _HitRing.singleInner),
      (0.50, 0.60, _HitRing.triple),
      (0.60, 0.87, _HitRing.singleOuter),
      (0.87, 1.00, _HitRing.double),
    ];

    const sectorAngle = 2 * math.pi / 20;
    final wedgeStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = AppColors.background.withValues(alpha: 0.4);

    for (var i = 0; i < 20; i++) {
      final start = -math.pi / 2 + (i * sectorAngle) - (sectorAngle / 2);
      final number = _sectorOrder[i];

      for (var ringIndex = 0; ringIndex < ringBounds.length; ringIndex++) {
        final ring = ringBounds[ringIndex];
        final inner = ring.$1 * radius;
        final outer = ring.$2 * radius;
        final isHighlight = _isSectorHighlighted(number, ring.$3);

        final baseColor = _ringColor(ring.$3, i, ringIndex);
        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = isHighlight
              ? AppColors.primary.withValues(alpha: 0.78)
              : baseColor;

        final path = Path()
          ..moveTo(
            center.dx + inner * math.cos(start),
            center.dy + inner * math.sin(start),
          )
          ..arcTo(
            Rect.fromCircle(center: center, radius: outer),
            start,
            sectorAngle,
            false,
          )
          ..lineTo(
            center.dx + inner * math.cos(start + sectorAngle),
            center.dy + inner * math.sin(start + sectorAngle),
          )
          ..arcTo(
            Rect.fromCircle(center: center, radius: inner),
            start + sectorAngle,
            -sectorAngle,
            false,
          )
          ..close();

        canvas.drawPath(path, paint);
        canvas.drawPath(path, wedgeStroke);
      }
    }

    final outerBullHighlight = previewHit?.ring == _HitRing.outerBull;
    final innerBullHighlight = previewHit?.ring == _HitRing.innerBull;

    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()
        ..color = outerBullHighlight
            ? AppColors.primary.withValues(alpha: 0.75)
            : AppColors.success.withValues(alpha: 0.88),
    );
    canvas.drawCircle(
      center,
      radius * 0.06,
      Paint()
        ..color = innerBullHighlight
            ? AppColors.primary.withValues(alpha: 0.9)
            : AppColors.error.withValues(alpha: 0.94),
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (var i = 0; i < 20; i++) {
      final angle = -math.pi / 2 + (i * sectorAngle);
      final number = _sectorOrder[i];
      final textRadius = radius * 0.95;
      final pos = Offset(
        center.dx + textRadius * math.cos(angle),
        center.dy + textRadius * math.sin(angle),
      );

      textPainter.text = TextSpan(
        text: '$number',
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
      );
    }
  }

  bool _isSectorHighlighted(int sectorNumber, _HitRing? ring) {
    if (previewHit == null || previewHit!.sectorNumber == null) {
      return false;
    }
    return previewHit!.sectorNumber == sectorNumber && previewHit!.ring == ring;
  }

  Color _ringColor(_HitRing? ring, int sectorIndex, int ringIndex) {
    if (ring == _HitRing.double || ring == _HitRing.triple) {
      return sectorIndex.isEven
          ? AppColors.error.withValues(alpha: 0.8)
          : AppColors.success.withValues(alpha: 0.8);
    }

    final base = ringIndex.isEven ? AppColors.card : AppColors.surface;
    return base.withValues(alpha: 0.95);
  }

  @override
  bool shouldRepaint(covariant _DartboardPainter oldDelegate) {
    final old = oldDelegate.previewHit;
    final current = previewHit;
    if (old == null && current == null) {
      return false;
    }
    return old?.score != current?.score ||
        old?.sectorNumber != current?.sectorNumber ||
        old?.ring != current?.ring;
  }
}
