import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';

class TempoDart {
  const TempoDart({
    required this.zone,
    required this.multiplier,
    required this.score,
    required this.label,
    required this.isMiss,
  });

  final int zone;
  final int multiplier;
  final int score;
  final String label;
  final bool isMiss;
}

class TempoVisit {
  const TempoVisit({
    required this.darts,
    required this.total,
    required this.doubleAttempts,
  });

  final List<TempoDart> darts;
  final int total;
  final int doubleAttempts;
}

class TempoScoreInput extends StatefulWidget {
  const TempoScoreInput({
    super.key,
    required this.maxScore,
    required this.onSubmitVisit,
    required this.canSelectZone,
    this.fillAvailableHeight = false,
    this.gridCrossAxisCount = 5,
    this.zones = const <int>[
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      25,
      50,
    ],
  });

  final int maxScore;
  final ValueChanged<TempoVisit> onSubmitVisit;
  final bool Function(int zone) canSelectZone;
  final List<int> zones;
  final bool fillAvailableHeight;
  final int gridCrossAxisCount;

  @override
  State<TempoScoreInput> createState() => _TempoScoreInputState();
}

class _TempoScoreInputState extends State<TempoScoreInput> {
  final List<TempoDart> _darts = <TempoDart>[];
  Timer? _pendingTimer;
  int? _pendingZone;
  int _pendingMultiplier = 0;

  @override
  void dispose() {
    _pendingTimer?.cancel();
    super.dispose();
  }

  int get _maxDarts => 3;
  bool get _canSubmit => _darts.length == _maxDarts;
  int get _total => _darts.fold<int>(0, (sum, hit) => sum + hit.score);
  int get _doubleAttempts =>
      _darts.where((d) => (!d.isMiss && d.multiplier == 2) || d.zone == 50).length;

  int _maxMultiplierForZone(int zone) {
    if (zone == 50) {
      return 1;
    }
    if (zone == 25) {
      return 2;
    }
    return 3;
  }

  TempoDart _toTempoDart({required int zone, required int multiplier}) {
    if (zone <= 0) {
      return const TempoDart(
        zone: 0,
        multiplier: 1,
        score: 0,
        label: '-',
        isMiss: true,
      );
    }

    if (zone == 50) {
      return const TempoDart(
        zone: 50,
        multiplier: 1,
        score: 50,
        label: 'DB',
        isMiss: false,
      );
    }

    if (zone == 25) {
      if (multiplier >= 2) {
        return const TempoDart(
          zone: 25,
          multiplier: 2,
          score: 50,
          label: 'DB',
          isMiss: false,
        );
      }
      return const TempoDart(
        zone: 25,
        multiplier: 1,
        score: 25,
        label: 'SB',
        isMiss: false,
      );
    }

    final prefix = switch (multiplier) {
      1 => 'S',
      2 => 'D',
      _ => 'T',
    };

    return TempoDart(
      zone: zone,
      multiplier: multiplier,
      score: zone * multiplier,
      label: '$prefix$zone',
      isMiss: false,
    );
  }

  void _onZoneTap(int zone) {
    if (_darts.length >= _maxDarts) {
      return;
    }
    if (!widget.canSelectZone(zone)) {
      return;
    }

    final maxMultiplier = _maxMultiplierForZone(zone);

    if (_pendingZone == zone) {
      _pendingMultiplier = (_pendingMultiplier + 1).clamp(1, maxMultiplier);
    } else {
      _commitPending();
      _pendingZone = zone;
      _pendingMultiplier = 1;
    }

    _pendingTimer?.cancel();
    _pendingTimer = Timer(const Duration(milliseconds: 520), _commitPending);
    setState(() {});
  }

  void _commitPending() {
    final zone = _pendingZone;
    final multiplier = _pendingMultiplier;
    if (zone == null || multiplier < 1) {
      return;
    }
    if (_darts.length >= _maxDarts) {
      _pendingZone = null;
      _pendingMultiplier = 0;
      _pendingTimer?.cancel();
      return;
    }

    _darts.add(_toTempoDart(zone: zone, multiplier: multiplier));

    _pendingZone = null;
    _pendingMultiplier = 0;
    _pendingTimer?.cancel();

    if (mounted) {
      setState(() {});
    }
  }

  void _onMiss() {
    _commitPending();
    if (_darts.length >= _maxDarts) {
      return;
    }
    _darts.add(_toTempoDart(zone: 0, multiplier: 1));
    setState(() {});
  }

  void _onBack() {
    if (_pendingZone != null) {
      _pendingZone = null;
      _pendingMultiplier = 0;
      _pendingTimer?.cancel();
      setState(() {});
      return;
    }
    if (_darts.isNotEmpty) {
      _darts.removeLast();
      setState(() {});
    }
  }

  void _onValidate() {
    _commitPending();
    if (!_canSubmit) {
      return;
    }

    final visit = TempoVisit(
      darts: List<TempoDart>.from(_darts),
      total: _total.clamp(0, widget.maxScore),
      doubleAttempts: _doubleAttempts,
    );

    widget.onSubmitVisit(visit);
    _darts.clear();
    setState(() {});
  }

  String _dartLabel(int index) {
    if (index >= _darts.length) {
      return '-';
    }
    return _darts[index].label;
  }

  String _pendingLabel() {
    final zone = _pendingZone;
    if (zone == null) {
      return '-';
    }
    if (zone == 50) {
      return 'DB';
    }
    if (zone == 25) {
      return _pendingMultiplier >= 2 ? 'DB' : 'SB';
    }
    final prefix = switch (_pendingMultiplier) {
      1 => 'S',
      2 => 'D',
      _ => 'T',
    };
    return '$prefix$zone';
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

          final label = isCurrent && _pendingZone != null
              ? _pendingLabel()
              : _dartLabel(index);

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  label,
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
        children: [
          _buildDartsHeader(),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'TOTAL $_total',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Text(
                _pendingZone == null ? '' : '${_pendingLabel()} ...',
                style: const TextStyle(
                  color: Color(0xFFF4CF38),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.fillAvailableHeight)
            Expanded(child: _buildGrid())
          else
            SizedBox(height: 260, child: _buildGrid()),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _onBack,
                  child: const Icon(Icons.undo),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _darts.length >= _maxDarts ? null : _onMiss,
                  child: const Icon(Icons.close),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _canSubmit ? _onValidate : null,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check),
                      SizedBox(width: 6),
                      Text('Valider'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      itemCount: widget.zones.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.gridCrossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: widget.gridCrossAxisCount <= 4 ? 1.5 : 1.2,
      ),
      itemBuilder: (context, index) {
        final zone = widget.zones[index];
        final enabled = widget.canSelectZone(zone);
        final label = switch (zone) {
          25 => 'SB',
          50 => 'DB',
          _ => '$zone',
        };
        return GestureDetector(
          onTap: enabled ? () => _onZoneTap(zone) : null,
          child: Container(
            decoration: BoxDecoration(
              color: enabled ? AppColors.card : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: enabled ? AppColors.surfaceLight : AppColors.textHint,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: enabled ? AppColors.textPrimary : AppColors.textHint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}
