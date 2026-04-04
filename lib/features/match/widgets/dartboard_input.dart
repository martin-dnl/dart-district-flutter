import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';

// ---------------------------------------------------------------------------
// Public models
// ---------------------------------------------------------------------------

/// Ring type of a dartboard zone.
enum DartRing { singleInner, triple, singleOuter, double, outerBull, innerBull }

/// Represents a single dart throw on the dartboard.
class DartHit {
  const DartHit({
    required this.normalizedPosition,
    required this.score,
    required this.label,
    required this.ring,
    this.sectorNumber,
  });

  /// Position on the board in normalised [0‥1] coordinates.
  final Offset normalizedPosition;
  final int score;
  final String label;
  final DartRing ring;
  final int? sectorNumber;
}

/// A complete 3‑dart visit, ready to be sent to the match engine.
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

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _DartboardInputState extends State<DartboardInput>
    with SingleTickerProviderStateMixin {
  // ── Dart tracking ──────────────────────────────────────────────────────
  final List<DartHit> _darts = [];

  // ── Aiming state ───────────────────────────────────────────────────────
  bool _isAiming = false;
  Offset _touchPoint = Offset.zero; // raw finger position (widget coords)
  Offset _focusPoint = Offset.zero; // lerped zoom centre
  double _currentZoom = 1.0;
  DartHit? _previewHit;

  // ── Animation ──────────────────────────────────────────────────────────
  late final Ticker _lerpTicker;

  // ── Layout ─────────────────────────────────────────────────────────────
  double _boardSize = 0;

  // ── Constants ──────────────────────────────────────────────────────────
  static const double _maxZoom = 3.0;
  static const double _focusLerp = 0.15;
  static const double _zoomLerp = 0.12;
  static const Duration _longPressDuration = Duration(milliseconds: 250);

  static const List<int> _sectorOrder = [
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

  // Ring radii (normalised to board radius = 1.0)
  static const double _innerBullR = 0.06;
  static const double _outerBullR = 0.12;
  static const double _singleInnerR = 0.50;
  static const double _tripleR = 0.60;
  static const double _singleOuterR = 0.87;

  // ── Computed properties ────────────────────────────────────────────────
  int get _total => _darts.fold<int>(0, (s, d) => s + d.score);
  bool get _canSubmit => _darts.length == 3;
  int get _doubleAttempts =>
      _darts.where((d) => d.ring == DartRing.double).length;

  // ── Lifecycle ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _lerpTicker = createTicker(_onTick);
  }

  @override
  void dispose() {
    if (_lerpTicker.isActive) _lerpTicker.stop();
    _lerpTicker.dispose();
    super.dispose();
  }

  // ── Ticker (smooth lerp + preview refresh) ────────────────────────────
  void _onTick(Duration _) {
    if (!_isAiming) return;

    final newFocus = Offset.lerp(_focusPoint, _touchPoint, _focusLerp)!;
    final targetZoom = _computeTargetZoom();
    final newZoom = lerpDouble(_currentZoom, targetZoom, _zoomLerp)!;

    // Recompute preview with updated zoom / focus.
    final boardPos = _screenToBoard(newFocus, newZoom, _touchPoint);
    final newHit = _computeHit(boardPos);

    setState(() {
      _focusPoint = newFocus;
      _currentZoom = newZoom;
      _previewHit = newHit;
    });
  }

  double _computeTargetZoom() {
    if (_boardSize <= 0) return _maxZoom;
    final radius = _boardSize / 2;
    final dx = _touchPoint.dx - radius;
    final dy = _touchPoint.dy - radius;
    final normalizedR = math.sqrt(dx * dx + dy * dy) / radius;

    // Slight de‑zoom near edges to indicate limit.
    if (normalizedR > 0.75) {
      final edgeFactor = ((normalizedR - 0.75) / 0.25).clamp(0.0, 1.0);
      return _maxZoom * (1.0 - edgeFactor * 0.35);
    }
    return _maxZoom;
  }

  // ── Coordinate helpers ─────────────────────────────────────────────────

  /// Converts a *screen* position (widget coords) to the corresponding point
  /// on the un‑zoomed board, given the current [focus] and [zoom].
  Offset _screenToBoard(Offset focus, double zoom, Offset screen) {
    if (zoom <= 1.01) return screen;
    return Offset(
      (screen.dx - focus.dx * (1 - zoom)) / zoom,
      (screen.dy - focus.dy * (1 - zoom)) / zoom,
    );
  }

  /// Detect which zone a board‑coordinate point falls on.
  DartHit? _computeHit(Offset boardPos) {
    if (_boardSize <= 0) return null;
    final radius = _boardSize / 2;
    final center = Offset(radius, radius);
    final dx = boardPos.dx - center.dx;
    final dy = boardPos.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final normalizedR = dist / radius;

    if (normalizedR > 1.0) return null;

    final zone = _detectZone(dx, dy, normalizedR);
    return DartHit(
      normalizedPosition: Offset(
        (boardPos.dx / _boardSize).clamp(0.0, 1.0),
        (boardPos.dy / _boardSize).clamp(0.0, 1.0),
      ),
      score: zone.score,
      label: zone.label,
      ring: zone.ring,
      sectorNumber: zone.sectorNumber,
    );
  }

  _ZoneResult _detectZone(double dx, double dy, double normalizedR) {
    if (normalizedR <= _innerBullR) {
      return const _ZoneResult(50, 'DBULL 50', DartRing.innerBull, null);
    }
    if (normalizedR <= _outerBullR) {
      return const _ZoneResult(25, 'SBULL 25', DartRing.outerBull, null);
    }

    final angle = (math.atan2(dx, -dy) + 2 * math.pi) % (2 * math.pi);
    const sectorWidth = 2 * math.pi / 20;
    final idx = ((angle + sectorWidth / 2) / sectorWidth).floor() % 20;
    final number = _sectorOrder[idx];

    DartRing ring;
    int multiplier;
    if (normalizedR <= _singleInnerR) {
      ring = DartRing.singleInner;
      multiplier = 1;
    } else if (normalizedR <= _tripleR) {
      ring = DartRing.triple;
      multiplier = 3;
    } else if (normalizedR <= _singleOuterR) {
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
    return _ZoneResult(score, '$prefix$number = $score', ring, number);
  }

  // ── Gesture handlers ───────────────────────────────────────────────────

  void _onLongPressStart(LongPressStartDetails details) {
    if (_darts.length >= 3) return;
    final pos = details.localPosition;
    setState(() {
      _isAiming = true;
      _touchPoint = pos;
      _focusPoint = pos; // no lerp delay on initial press
      _currentZoom = 1.0; // will animate to target
      _previewHit = _computeHit(pos); // zoom = 1 → board = screen
    });
    if (!_lerpTicker.isActive) _lerpTicker.start();
  }

  void _onLongPressMove(LongPressMoveUpdateDetails details) {
    if (!_isAiming) return;
    final pos = details.localPosition;

    // Cancel if finger leaves widget bounds (with small tolerance).
    if (pos.dx < -20 ||
        pos.dy < -20 ||
        pos.dx > _boardSize + 20 ||
        pos.dy > _boardSize + 20) {
      _cancelAiming();
      return;
    }

    setState(() => _touchPoint = pos);
    // Preview is refreshed every frame by the ticker.
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    if (!_isAiming) return;
    final hit = _previewHit;
    if (hit != null) {
      _addDart(hit);
    }
    // If hit == null the finger was outside the board → cancel, nothing recorded.
    _stopAiming();
  }

  void _cancelAiming() => _stopAiming();

  void _stopAiming() {
    if (_lerpTicker.isActive) _lerpTicker.stop();
    setState(() {
      _isAiming = false;
      _previewHit = null;
      _currentZoom = 1.0;
    });
  }

  // ── Dart management ────────────────────────────────────────────────────

  void _addDart(DartHit hit) {
    if (_darts.length >= 3) return;
    setState(() => _darts.add(hit));
  }

  void _addMiss() {
    if (_darts.length >= 3) return;
    setState(() {
      _darts.add(
        const DartHit(
          normalizedPosition: Offset.zero,
          score: 0,
          label: 'Miss',
          ring: DartRing.singleOuter,
        ),
      );
    });
  }

  void _undoLastDart() {
    if (_darts.isEmpty) return;
    setState(() => _darts.removeLast());
  }

  void _submitVisit() {
    if (!_canSubmit) return;
    final total = _total.clamp(0, widget.maxScore);
    widget.onSubmitVisit(
      DartboardVisit(
        darts: _darts.map((d) => d.score).toList(),
        total: total,
        doubleAttempts: _doubleAttempts,
      ),
    );
    setState(() => _darts.clear());
  }

  // ── Build ──────────────────────────────────────────────────────────────

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
        children: [
          _buildVisitSummary(),
          const SizedBox(height: 6),
          if (widget.fillAvailableHeight)
            Expanded(child: _buildBoard())
          else
            _buildBoard(),
          const SizedBox(height: 6),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildVisitSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List<Widget>.generate(3, (i) {
              final has = i < _darts.length;
              return Expanded(
                child: Container(
                  height: 38,
                  margin: EdgeInsets.only(right: i == 2 ? 0 : 8),
                  decoration: BoxDecoration(
                    color: has
                        ? AppColors.primary.withValues(alpha: 0.14)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: has ? AppColors.primary : AppColors.stroke,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    has ? '${_darts[i].score}' : '-',
                    style: TextStyle(
                      color: has ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: $_total',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_total > widget.maxScore)
                const Text(
                  'Bust',
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

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = math.min(constraints.maxWidth, constraints.maxHeight);
        final size = available.clamp(200.0, 500.0);
        _boardSize = size;

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: RawGestureDetector(
              gestures: <Type, GestureRecognizerFactory>{
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      LongPressGestureRecognizer
                    >(
                      () => LongPressGestureRecognizer(
                        duration: _longPressDuration,
                      ),
                      (LongPressGestureRecognizer instance) {
                        instance
                          ..onLongPressStart = _onLongPressStart
                          ..onLongPressMoveUpdate = _onLongPressMove
                          ..onLongPressEnd = _onLongPressEnd;
                      },
                    ),
              },
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ── Zoomed board ──
                    Transform(
                      transform: _buildZoomMatrix(),
                      child: CustomPaint(
                        size: Size(size, size),
                        painter: _DartboardPainter(highlightedHit: _previewHit),
                      ),
                    ),

                    // ── Crosshair ──
                    if (_isAiming)
                      Positioned(
                        left: _touchPoint.dx - 14,
                        top: _touchPoint.dy - 14,
                        child: IgnorePointer(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                      ),

                    // ── Value label ──
                    if (_isAiming && _previewHit != null)
                      Positioned(
                        left: (_touchPoint.dx - 48).clamp(0.0, size - 96),
                        top: (_touchPoint.dy - 50).clamp(0.0, size - 28),
                        child: IgnorePointer(
                          child: Container(
                            width: 96,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.background.withValues(
                                alpha: 0.92,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Text(
                              _previewHit!.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // ── Hint (when not aiming) ──
                    if (!_isAiming && _darts.length < 3)
                      Center(
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Appui long pour viser',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
        );
      },
    );
  }

  Matrix4 _buildZoomMatrix() {
    if (!_isAiming || _currentZoom <= 1.01) return Matrix4.identity();
    final fx = _focusPoint.dx;
    final fy = _focusPoint.dy;
    final s = _currentZoom;
    // Scale around focus point: keeps focus point at same screen position.
    return Matrix4.identity()
      ..translate(fx * (1 - s), fy * (1 - s), 0.0)
      ..scale(s, s, 1.0);
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _darts.isEmpty ? null : _undoLastDart,
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Retour'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _darts.length >= 3 ? null : _addMiss,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Miss'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: _canSubmit ? _submitVisit : null,
            icon: const Icon(Icons.check, size: 18),
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

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

class _ZoneResult {
  const _ZoneResult(this.score, this.label, this.ring, this.sectorNumber);
  final int score;
  final String label;
  final DartRing ring;
  final int? sectorNumber;
}

// ---------------------------------------------------------------------------
// CustomPainter — standard dartboard
// ---------------------------------------------------------------------------

class _DartboardPainter extends CustomPainter {
  const _DartboardPainter({required this.highlightedHit});

  final DartHit? highlightedHit;

  static const List<int> _sectorOrder = [
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

  // Standard dartboard colours
  static const Color _darkSingle = Color(0xFF1A1A2E);
  static const Color _lightSingle = Color(0xFFF5E6CA);
  static const Color _redRing = Color(0xFFE53935);
  static const Color _greenRing = Color(0xFF43A047);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF0D0D1A));

    const sectorAngle = 2 * math.pi / 20;
    final wire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = const Color(0xFF777777);

    // Ring boundaries (innerR, outerR, ringName for highlight matching)
    const rings = <(double, double, String)>[
      (0.12, 0.50, 'singleInner'),
      (0.50, 0.60, 'triple'),
      (0.60, 0.87, 'singleOuter'),
      (0.87, 1.00, 'double'),
    ];

    for (var i = 0; i < 20; i++) {
      final start = -math.pi / 2 + i * sectorAngle - sectorAngle / 2;
      final number = _sectorOrder[i];

      for (final (innerR, outerR, ringName) in rings) {
        final inner = innerR * radius;
        final outer = outerR * radius;
        final highlighted = _isHighlighted(number, ringName);
        final base = _sectorColor(ringName, i);

        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = highlighted
              ? AppColors.primary.withValues(alpha: 0.82)
              : base;

        final path = _wedgePath(center, inner, outer, start, sectorAngle);
        canvas.drawPath(path, paint);
        canvas.drawPath(path, wire);
      }
    }

    // ── Outer bull ──
    final outerH = highlightedHit?.ring == DartRing.outerBull;
    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()
        ..color = outerH
            ? AppColors.primary.withValues(alpha: 0.8)
            : _greenRing,
    );
    canvas.drawCircle(center, radius * 0.12, wire);

    // ── Inner bull ──
    final innerH = highlightedHit?.ring == DartRing.innerBull;
    canvas.drawCircle(
      center,
      radius * 0.06,
      Paint()
        ..color = innerH ? AppColors.primary.withValues(alpha: 0.9) : _redRing,
    );
    canvas.drawCircle(center, radius * 0.06, wire);

    // ── Sector numbers ──
    _paintNumbers(canvas, center, radius);
  }

  Path _wedgePath(
    Offset c,
    double inner,
    double outer,
    double start,
    double sweep,
  ) {
    return Path()
      ..moveTo(c.dx + inner * math.cos(start), c.dy + inner * math.sin(start))
      ..arcTo(Rect.fromCircle(center: c, radius: outer), start, sweep, false)
      ..lineTo(
        c.dx + inner * math.cos(start + sweep),
        c.dy + inner * math.sin(start + sweep),
      )
      ..arcTo(
        Rect.fromCircle(center: c, radius: inner),
        start + sweep,
        -sweep,
        false,
      )
      ..close();
  }

  bool _isHighlighted(int sectorNumber, String ringName) {
    final hit = highlightedHit;
    if (hit == null || hit.sectorNumber == null) return false;
    final hitRing = switch (hit.ring) {
      DartRing.singleInner => 'singleInner',
      DartRing.triple => 'triple',
      DartRing.singleOuter => 'singleOuter',
      DartRing.double => 'double',
      _ => '',
    };
    return hit.sectorNumber == sectorNumber && hitRing == ringName;
  }

  Color _sectorColor(String ringName, int sectorIdx) {
    if (ringName == 'double' || ringName == 'triple') {
      return sectorIdx.isEven ? _redRing : _greenRing;
    }
    return sectorIdx.isEven ? _darkSingle : _lightSingle;
  }

  void _paintNumbers(Canvas canvas, Offset center, double radius) {
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    const sectorAngle = 2 * math.pi / 20;
    final r = radius * 0.95;

    for (var i = 0; i < 20; i++) {
      final a = -math.pi / 2 + i * sectorAngle;
      final pos = Offset(
        center.dx + r * math.cos(a),
        center.dy + r * math.sin(a),
      );

      tp.text = TextSpan(
        text: '${_sectorOrder[i]}',
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DartboardPainter old) {
    if (old.highlightedHit == null && highlightedHit == null) return false;
    return old.highlightedHit?.score != highlightedHit?.score ||
        old.highlightedHit?.sectorNumber != highlightedHit?.sectorNumber ||
        old.highlightedHit?.ring != highlightedHit?.ring;
  }
}
