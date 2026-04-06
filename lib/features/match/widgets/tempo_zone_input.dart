import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';

class TempoZoneShot {
  const TempoZoneShot({
    required this.zone,
    required this.multiplier,
    required this.isMiss,
  });

  final int zone;
  final int multiplier;
  final bool isMiss;

  int get value {
    if (isMiss) {
      return 0;
    }
    final zoneValue = zone == 25 ? 25 : zone;
    return zoneValue * multiplier;
  }

  String get label {
    if (isMiss) {
      return 'MISS';
    }
    final prefix = switch (multiplier) {
      1 => 'S',
      2 => 'D',
      _ => 'T',
    };
    return '$prefix${zone == 25 ? 'B' : zone}';
  }
}

class TempoZoneInput extends StatefulWidget {
  const TempoZoneInput({
    super.key,
    required this.remainingDarts,
    required this.onSubmit,
    required this.canSelectZone,
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
    ],
  });

  final int remainingDarts;
  final void Function(List<TempoZoneShot> shots) onSubmit;
  final bool Function(int zone) canSelectZone;
  final List<int> zones;

  @override
  State<TempoZoneInput> createState() => _TempoZoneInputState();
}

class _TempoZoneInputState extends State<TempoZoneInput> {
  final List<TempoZoneShot> _shots = <TempoZoneShot>[];
  Timer? _pendingTimer;
  int? _pendingZone;
  int _pendingMultiplier = 0;

  @override
  void didUpdateWidget(covariant TempoZoneInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remainingDarts < _shots.length) {
      _shots.clear();
      _pendingZone = null;
      _pendingMultiplier = 0;
      _pendingTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _pendingTimer?.cancel();
    super.dispose();
  }

  int get _maxShots => widget.remainingDarts.clamp(0, 3);
  int get _total => _shots.fold<int>(0, (sum, shot) => sum + shot.value);

  void _onZoneTap(int zone) {
    if (_shots.length >= _maxShots) {
      return;
    }
    if (!widget.canSelectZone(zone)) {
      return;
    }

    if (_pendingZone == zone) {
      _pendingMultiplier = (_pendingMultiplier + 1).clamp(1, 3);
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
    if (_shots.length >= _maxShots) {
      _pendingZone = null;
      _pendingMultiplier = 0;
      _pendingTimer?.cancel();
      return;
    }

    _shots.add(
      TempoZoneShot(
        zone: zone,
        multiplier: multiplier,
        isMiss: false,
      ),
    );

    _pendingZone = null;
    _pendingMultiplier = 0;
    _pendingTimer?.cancel();

    if (mounted) {
      setState(() {});
    }
  }

  void _onMiss() {
    _commitPending();
    if (_shots.length >= _maxShots) {
      return;
    }
    _shots.add(const TempoZoneShot(zone: 0, multiplier: 1, isMiss: true));
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
    if (_shots.isNotEmpty) {
      _shots.removeLast();
      setState(() {});
    }
  }

  void _onValidate() {
    _commitPending();
    if (_shots.isEmpty) {
      return;
    }
    widget.onSubmit(List<TempoZoneShot>.from(_shots));
    _shots.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pendingLabel = _pendingZone == null
        ? null
        : '${switch (_pendingMultiplier) { 1 => 'S', 2 => 'D', _ => 'T' }}${_pendingZone == 25 ? 'B' : _pendingZone}';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Saisie tempo (${_shots.length}/$_maxShots)',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Total $_total',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final shot in _shots)
                    _ShotChip(label: shot.label, value: shot.value),
                  if (pendingLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Text(
                        '$pendingLabel ...',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            itemCount: widget.zones.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.2,
            ),
            itemBuilder: (context, index) {
              final zone = widget.zones[index];
              final enabled = widget.canSelectZone(zone);
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
                    zone == 25 ? 'Bull' : '$zone',
                    style: TextStyle(
                      color: enabled ? AppColors.textPrimary : AppColors.textHint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _onBack,
                icon: const Icon(Icons.undo),
                label: const Text('Retour'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _onMiss,
                icon: const Icon(Icons.block),
                label: const Text('Miss (0)'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: _onValidate,
                icon: const Icon(Icons.check),
                label: const Text('Valider'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ShotChip extends StatelessWidget {
  const _ShotChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Text(
        '$label = $value',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
