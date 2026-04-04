import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';

enum DartRing { singleInner, triple, singleOuter, double, outerBull, innerBull }

class DartHit {
  const DartHit({
    required this.normalizedPosition,
    required this.score,
    required this.label,
    required this.ring,
    this.sectorNumber,
  });

  final Offset normalizedPosition;
  final int score;
  final String label;
  final DartRing ring;
  final int? sectorNumber;
}

class DartboardVisit {
  const DartboardVisit({
    required this.darts,
    required this.total,
    required this.doubleAttempts,
    required this.dartHits,
  });

  final List<int> darts;
  final int total;
  final int doubleAttempts;
  final List<DartHit> dartHits;
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
  final List<DartHit> _darts = <DartHit>[];

  bool _isAiming = false;
  Offset _touchPoint = Offset.zero;
  Offset _focusPoint = Offset.zero;
  double _currentZoom = 1.0;
  DartHit? _previewHit;

  Rect _boardRect = Rect.zero;

  static const double _maxZoom = 3.0;
  static const Duration _longPressDuration = Duration(milliseconds: 230);

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

  // Official proportions (relative to double outer = 170 mm)
  static const double _rInnerBull = 6.35 / 170.0;
  static const double _rOuterBull = 15.9 / 170.0;
  static const double _rTripleInner = 99.0 / 170.0;
  static const double _rTripleOuter = 107.0 / 170.0;
  static const double _rDoubleInner = 162.0 / 170.0;

  static const double _playableRatio = 0.82;

  static const Color _boardOuterBlack = Color(0xFF050505);
  static const Color _blackSegment = Color(0xFF020202);
  static const Color _beigeSegment = Color(0xFFD9CFB0);
  static const Color _ringRed = Color(0xFFE96A73);
  static const Color _ringGreen = Color(0xFF5EC796);
  static const Color _wireWhite = Color(0xFFECECEC);
  static const Color _markerBlue = Color(0xFF3CA9FF);

  int get _total => _darts.fold<int>(0, (sum, hit) => sum + hit.score);
  bool get _canSubmit => _darts.length == 3;
  int get _doubleAttempts =>
      _darts.where((hit) => hit.ring == DartRing.double).length;

  double _computeTargetZoom(Offset position) {
    if (_boardRect.isEmpty) {
      return _maxZoom;
    }

    final local = position - _boardRect.topLeft;
    final center = Offset(_boardRect.width / 2, _boardRect.height / 2);
    final playableRadius = (_boardRect.width / 2) * _playableRatio;

    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    final r = math.sqrt(dx * dx + dy * dy) / playableRadius;

    if (r > 0.78) {
      final edgeFactor = ((r - 0.78) / 0.22).clamp(0.0, 1.0);
      return _maxZoom * (1.0 - edgeFactor * 0.30);
    }

    return _maxZoom;
  }

  Offset _screenToBoard(Offset focus, double zoom, Offset screen) {
    if (zoom <= 1.01) {
      return screen;
    }

    return Offset(
      (screen.dx - focus.dx * (1 - zoom)) / zoom,
      (screen.dy - focus.dy * (1 - zoom)) / zoom,
    );
  }

  DartHit? _computeHit(Offset boardPointInViewport) {
    if (_boardRect.isEmpty) {
      return null;
    }

    final local = boardPointInViewport - _boardRect.topLeft;
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > _boardRect.width ||
        local.dy > _boardRect.height) {
      return null;
    }

    final center = Offset(_boardRect.width / 2, _boardRect.height / 2);
    final playableRadius = (_boardRect.width / 2) * _playableRatio;

    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final normalizedR = distance / playableRadius;

    if (normalizedR > 1.0) {
      return null;
    }

    final zone = _detectZone(dx, dy, normalizedR);

    return DartHit(
      normalizedPosition: Offset(
        (local.dx / _boardRect.width).clamp(0.0, 1.0),
        (local.dy / _boardRect.height).clamp(0.0, 1.0),
      ),
      score: zone.score,
      label: zone.label,
      ring: zone.ring,
      sectorNumber: zone.sectorNumber,
    );
  }

  _ZoneResult _detectZone(double dx, double dy, double normalizedR) {
    if (normalizedR <= _rInnerBull) {
      return const _ZoneResult(
        score: 50,
        label: 'D25',
        ring: DartRing.innerBull,
      );
    }

    if (normalizedR <= _rOuterBull) {
      return const _ZoneResult(
        score: 25,
        label: '25',
        ring: DartRing.outerBull,
      );
    }

    final angle = (math.atan2(dx, -dy) + (2 * math.pi)) % (2 * math.pi);
    const sectorWidth = 2 * math.pi / 20;
    final sectorIndex = ((angle + sectorWidth / 2) / sectorWidth).floor() % 20;
    final number = _sectorOrder[sectorIndex];

    DartRing ring;
    int multiplier;

    if (normalizedR < _rTripleInner) {
      ring = DartRing.singleInner;
      multiplier = 1;
    } else if (normalizedR <= _rTripleOuter) {
      ring = DartRing.triple;
      multiplier = 3;
    } else if (normalizedR < _rDoubleInner) {
      ring = DartRing.singleOuter;
      multiplier = 1;
    } else {
      ring = DartRing.double;
      multiplier = 2;
    }

    final score = number * multiplier;
    final prefix = switch (multiplier) {
      2 => 'D',
      3 => 'T',
      _ => 'S',
    };

    return _ZoneResult(
      score: score,
      label: '$prefix$number',
      ring: ring,
      sectorNumber: number,
    );
  }

  void _onTapUp(TapUpDetails details) {
    if (_isAiming || _darts.length >= 3) {
      return;
    }

    final hit = _computeHit(details.localPosition);
    if (hit != null) {
      _addDart(hit);
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (_darts.length >= 3) {
      return;
    }

    final pos = details.localPosition;
    final zoom = _computeTargetZoom(pos);
    final boardPoint = _screenToBoard(pos, zoom, pos);

    setState(() {
      _isAiming = true;
      _touchPoint = pos;
      _focusPoint = pos;
      _currentZoom = zoom;
      _previewHit = _computeHit(boardPoint);
    });
  }

  void _onLongPressMove(LongPressMoveUpdateDetails details) {
    if (!_isAiming) {
      return;
    }

    final pos = details.localPosition;
    final zoom = _computeTargetZoom(pos);
    final boardPoint = _screenToBoard(pos, zoom, pos);
    final local = boardPoint - _boardRect.topLeft;

    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > _boardRect.width ||
        local.dy > _boardRect.height) {
      _cancelAiming();
      return;
    }

    setState(() {
      _touchPoint = pos;
      _focusPoint = pos;
      _currentZoom = zoom;
      _previewHit = _computeHit(boardPoint);
    });
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    if (!_isAiming) {
      return;
    }

    final hit = _previewHit;
    if (hit != null) {
      _addDart(hit);
    }

    _stopAiming();
  }

  void _cancelAiming() {
    _stopAiming();
  }

  void _stopAiming() {
    setState(() {
      _isAiming = false;
      _previewHit = null;
      _currentZoom = 1.0;
    });
  }

  void _addDart(DartHit hit) {
    if (_darts.length >= 3) {
      return;
    }

    setState(() {
      _darts.add(hit);
    });
  }

  void _addMiss() {
    if (_darts.length >= 3) {
      return;
    }

    setState(() {
      _darts.add(
        const DartHit(
          normalizedPosition: Offset.zero,
          score: 0,
          label: '-',
          ring: DartRing.singleOuter,
        ),
      );
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

    widget.onSubmitVisit(
      DartboardVisit(
        darts: _darts.map((hit) => hit.score).toList(),
        total: _total.clamp(0, widget.maxScore),
        doubleAttempts: _doubleAttempts,
        dartHits: List<DartHit>.from(_darts),
      ),
    );

    setState(() {
      _darts.clear();
    });
  }

  String _dartLabel(int index) {
    if (index >= _darts.length) {
      return '-';
    }
    final hit = _darts[index];
    if (hit.label == '-' || hit.score == 0) {
      return '-';
    }
    return hit.label;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
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
        children: <Widget>[
          _buildDartsHeader(),
          const SizedBox(height: 4),
          if (widget.fillAvailableHeight)
            Expanded(child: _buildBoardArea())
          else
            SizedBox(height: 360, child: _buildBoardArea()),
          const SizedBox(height: 8),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildDartsHeader() {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: Row(
        children: List<Widget>.generate(3, (index) {
          final isCurrent = index == _darts.length && index < 3;
          final valueColor = isCurrent
              ? const Color(0xFFF4CF38)
              : AppColors.textPrimary;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  _dartLabel(index),
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'DART ${index + 1}',
                  style: TextStyle(
                    color: isCurrent
                        ? const Color(0xFFF4CF38)
                        : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBoardArea() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        final drawSize = _isAiming
            ? math.max(viewportSize.width, viewportSize.height) * 1.50
            : math.min(viewportSize.width, viewportSize.height) * 1.10;

        final boardRect = Rect.fromCenter(
          center: viewportSize.center(Offset.zero),
          width: drawSize,
          height: drawSize,
        );

        _boardRect = boardRect;

        return RawGestureDetector(
          gestures: <Type, GestureRecognizerFactory>{
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer
                >(
                  () =>
                      LongPressGestureRecognizer(duration: _longPressDuration),
                  (LongPressGestureRecognizer instance) {
                    instance
                      ..onLongPressStart = _onLongPressStart
                      ..onLongPressMoveUpdate = _onLongPressMove
                      ..onLongPressEnd = _onLongPressEnd;
                  },
                ),
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  TapGestureRecognizer.new,
                  (TapGestureRecognizer instance) {
                    instance.onTapUp = _onTapUp;
                  },
                ),
          },
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Transform(
                transform: _buildZoomMatrix(),
                child: CustomPaint(
                  painter: _DartboardPainter(
                    boardRect: boardRect,
                    highlightedHit: _previewHit,
                    dartMarkers: _darts,
                    playableRatio: _playableRatio,
                    rInnerBull: _rInnerBull,
                    rOuterBull: _rOuterBull,
                    rTripleInner: _rTripleInner,
                    rTripleOuter: _rTripleOuter,
                    rDoubleInner: _rDoubleInner,
                    boardOuterBlack: _boardOuterBlack,
                    blackSegment: _blackSegment,
                    beigeSegment: _beigeSegment,
                    ringRed: _ringRed,
                    ringGreen: _ringGreen,
                    wireWhite: _wireWhite,
                    markerBlue: _markerBlue,
                    sectorOrder: _sectorOrder,
                  ),
                ),
              ),

              Positioned(
                left: 8,
                top: 8,
                child: GestureDetector(
                  onTap: _darts.isEmpty ? null : _undoLastDart,
                  child: Opacity(
                    opacity: _darts.isEmpty ? 0.35 : 1.0,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.60),
                        ),
                      ),
                      child: const Icon(
                        Icons.undo_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                ),
              ),

              if (_isAiming)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _AimAxesPainter(
                        point: _touchPoint,
                        label: _previewHit?.label,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Matrix4 _buildZoomMatrix() {
    if (!_isAiming || _currentZoom <= 1.01) {
      return Matrix4.identity();
    }

    final fx = _focusPoint.dx;
    final fy = _focusPoint.dy;
    final scale = _currentZoom;

    return Matrix4.identity()
      ..translate(fx * (1 - scale), fy * (1 - scale), 0)
      ..scale(scale, scale, 1.0);
  }

  Widget _buildActions() {
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton(
            onPressed: _darts.length >= 3 ? null : _addMiss,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3D3E42),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text(
              'NO SCORE',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: _canSubmit ? _submitVisit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text(
              'VALIDER',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoneResult {
  const _ZoneResult({
    required this.score,
    required this.label,
    required this.ring,
    this.sectorNumber,
  });

  final int score;
  final String label;
  final DartRing ring;
  final int? sectorNumber;
}

class _DartboardPainter extends CustomPainter {
  const _DartboardPainter({
    required this.boardRect,
    required this.highlightedHit,
    required this.dartMarkers,
    required this.playableRatio,
    required this.rInnerBull,
    required this.rOuterBull,
    required this.rTripleInner,
    required this.rTripleOuter,
    required this.rDoubleInner,
    required this.boardOuterBlack,
    required this.blackSegment,
    required this.beigeSegment,
    required this.ringRed,
    required this.ringGreen,
    required this.wireWhite,
    required this.markerBlue,
    required this.sectorOrder,
  });

  final Rect boardRect;
  final DartHit? highlightedHit;
  final List<DartHit> dartMarkers;

  final double playableRatio;
  final double rInnerBull;
  final double rOuterBull;
  final double rTripleInner;
  final double rTripleOuter;
  final double rDoubleInner;

  final Color boardOuterBlack;
  final Color blackSegment;
  final Color beigeSegment;
  final Color ringRed;
  final Color ringGreen;
  final Color wireWhite;
  final Color markerBlue;

  final List<int> sectorOrder;

  @override
  void paint(Canvas canvas, Size size) {
    if (boardRect.isEmpty) {
      return;
    }

    final center = boardRect.center;
    final outerRadius = boardRect.width / 2;
    final playableRadius = outerRadius * playableRatio;

    const sectorSweep = 2 * math.pi / 20;
    final wirePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = wireWhite;

    canvas.drawCircle(center, outerRadius, Paint()..color = boardOuterBlack);
    canvas.drawCircle(center, playableRadius, Paint()..color = blackSegment);

    for (var i = 0; i < 20; i++) {
      final number = sectorOrder[i];
      final start = -math.pi / 2 + i * sectorSweep - (sectorSweep / 2);

      _drawSectorRing(
        canvas: canvas,
        center: center,
        start: start,
        sweep: sectorSweep,
        innerRatio: rOuterBull,
        outerRatio: rTripleInner,
        fill: i.isEven ? beigeSegment : blackSegment,
        highlighted: _isHighlighted(number, DartRing.singleInner),
      );

      _drawSectorRing(
        canvas: canvas,
        center: center,
        start: start,
        sweep: sectorSweep,
        innerRatio: rTripleInner,
        outerRatio: rTripleOuter,
        fill: i.isEven ? ringGreen : ringRed,
        highlighted: _isHighlighted(number, DartRing.triple),
      );

      _drawSectorRing(
        canvas: canvas,
        center: center,
        start: start,
        sweep: sectorSweep,
        innerRatio: rTripleOuter,
        outerRatio: rDoubleInner,
        fill: i.isEven ? blackSegment : beigeSegment,
        highlighted: _isHighlighted(number, DartRing.singleOuter),
      );

      _drawSectorRing(
        canvas: canvas,
        center: center,
        start: start,
        sweep: sectorSweep,
        innerRatio: rDoubleInner,
        outerRatio: 1.0,
        fill: i.isEven ? ringRed : ringGreen,
        highlighted: _isHighlighted(number, DartRing.double),
      );
    }

    canvas.drawCircle(center, playableRadius, wirePaint);
    canvas.drawCircle(center, playableRadius * rDoubleInner, wirePaint);
    canvas.drawCircle(center, playableRadius * rTripleOuter, wirePaint);
    canvas.drawCircle(center, playableRadius * rTripleInner, wirePaint);
    canvas.drawCircle(center, playableRadius * rOuterBull, wirePaint);

    final isOuterBull = highlightedHit?.ring == DartRing.outerBull;
    final isInnerBull = highlightedHit?.ring == DartRing.innerBull;

    canvas.drawCircle(
      center,
      playableRadius * rOuterBull,
      Paint()
        ..color = isOuterBull
            ? AppColors.primary.withValues(alpha: 0.78)
            : ringGreen,
    );

    canvas.drawCircle(
      center,
      playableRadius * rInnerBull,
      Paint()
        ..color = isInnerBull
            ? AppColors.primary.withValues(alpha: 0.88)
            : ringRed,
    );

    canvas.drawCircle(center, playableRadius * rOuterBull, wirePaint);
    canvas.drawCircle(center, playableRadius * rInnerBull, wirePaint);

    _drawNumbers(canvas, center, playableRadius, outerRadius);
    _drawDartMarkers(canvas);
  }

  void _drawSectorRing({
    required Canvas canvas,
    required Offset center,
    required double start,
    required double sweep,
    required double innerRatio,
    required double outerRatio,
    required Color fill,
    required bool highlighted,
  }) {
    final playableRadius = (boardRect.width / 2) * playableRatio;
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
        ..color = highlighted
            ? AppColors.primary.withValues(alpha: 0.82)
            : fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..color = wireWhite,
    );
  }

  bool _isHighlighted(int number, DartRing ring) {
    final hit = highlightedHit;
    if (hit == null || hit.sectorNumber == null) {
      return false;
    }
    return hit.sectorNumber == number && hit.ring == ring;
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
        text: '${sectorOrder[i]}',
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

  void _drawDartMarkers(Canvas canvas) {
    for (final hit in dartMarkers) {
      if (hit.score == 0) {
        continue;
      }

      final pos = Offset(
        boardRect.left + (hit.normalizedPosition.dx * boardRect.width),
        boardRect.top + (hit.normalizedPosition.dy * boardRect.height),
      );

      canvas.drawCircle(
        pos,
        boardRect.width * 0.0105,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        pos,
        boardRect.width * 0.0075,
        Paint()..color = markerBlue,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DartboardPainter oldDelegate) {
    return oldDelegate.highlightedHit?.score != highlightedHit?.score ||
        oldDelegate.highlightedHit?.sectorNumber !=
            highlightedHit?.sectorNumber ||
        oldDelegate.highlightedHit?.ring != highlightedHit?.ring ||
        oldDelegate.boardRect != boardRect ||
        oldDelegate.dartMarkers.length != dartMarkers.length ||
        oldDelegate.dartMarkers.hashCode != dartMarkers.hashCode;
  }
}

class _AimAxesPainter extends CustomPainter {
  const _AimAxesPainter({required this.point, required this.label});

  final Offset point;
  final String? label;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..strokeWidth = 1.35;

    canvas.drawLine(
      Offset(0, point.dy),
      Offset(size.width, point.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(point.dx, 0),
      Offset(point.dx, size.height),
      axisPaint,
    );

    canvas.drawCircle(
      point,
      4.5,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );

    if (label != null && label!.isNotEmpty) {
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      )..layout(maxWidth: size.width - 24);

      final dx = (point.dx - (tp.width / 2)).clamp(
        12.0,
        size.width - tp.width - 12,
      );
      final dy = (point.dy - tp.height - 16).clamp(
        10.0,
        size.height - tp.height - 10,
      );

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx, dy, tp.width + 14, tp.height + 8),
        const Radius.circular(12),
      );

      canvas.drawRRect(
        rect,
        Paint()..color = Colors.white.withValues(alpha: 0.96),
      );
      tp.paint(canvas, Offset(dx + 7, dy + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _AimAxesPainter oldDelegate) {
    return oldDelegate.point != point || oldDelegate.label != label;
  }
}
