import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';

class OpeningHoursInput extends StatefulWidget {
  const OpeningHoursInput({
    super.key,
    required this.onChanged,
    this.initialValue,
  });

  final ValueChanged<Map<String, dynamic>> onChanged;
  final Map<String, dynamic>? initialValue;

  @override
  State<OpeningHoursInput> createState() => _OpeningHoursInputState();
}

class _OpeningHoursInputState extends State<OpeningHoursInput> {
  static const _days = <_DayConfig>[
    _DayConfig('monday', 'Lundi'),
    _DayConfig('tuesday', 'Mardi'),
    _DayConfig('wednesday', 'Mercredi'),
    _DayConfig('thursday', 'Jeudi'),
    _DayConfig('friday', 'Vendredi'),
    _DayConfig('saturday', 'Samedi'),
    _DayConfig('sunday', 'Dimanche'),
  ];

  late Map<String, _DayValue> _values;

  @override
  void initState() {
    super.initState();
    _values = {
      for (final day in _days) day.key: const _DayValue(),
    };

    final initial = widget.initialValue ?? const <String, dynamic>{};
    for (final entry in initial.entries) {
      final item = entry.value;
      if (item is! Map) {
        continue;
      }
      final open = (item['open'] ?? '').toString();
      final close = (item['close'] ?? '').toString();
      if (open.isEmpty || close.isEmpty) {
        continue;
      }
      _values[entry.key] = _DayValue(enabled: true, open: open, close: close);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _emitChange());
  }

  Future<void> _pickTime(String dayKey, bool isOpen) async {
    final dayValue = _values[dayKey] ?? const _DayValue();
    final source = isOpen ? dayValue.open : dayValue.close;
    final initial = _parseTime(source) ?? const TimeOfDay(hour: 18, minute: 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) {
      return;
    }

    final formatted = _formatTime(picked);
    setState(() {
      _values[dayKey] = _DayValue(
        enabled: true,
        open: isOpen ? formatted : dayValue.open,
        close: isOpen ? dayValue.close : formatted,
      );
    });
    _emitChange();
  }

  TimeOfDay? _parseTime(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _emitChange() {
    final map = <String, dynamic>{};
    for (final day in _days) {
      final value = _values[day.key] ?? const _DayValue();
      if (!value.enabled) {
        continue;
      }

      map[day.key] = {
        'open': value.open,
        'close': value.close,
      };
    }
    widget.onChanged(map);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _days.map((day) {
        final value = _values[day.key] ?? const _DayValue();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        day.label,
                        style: GoogleFonts.manrope(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: value.enabled,
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withValues(alpha: 0.35),
                      onChanged: (enabled) {
                        setState(() {
                          _values[day.key] = enabled
                              ? _DayValue(
                                  enabled: true,
                                  open: value.open,
                                  close: value.close,
                                )
                              : const _DayValue(enabled: false);
                        });
                        _emitChange();
                      },
                    ),
                  ],
                ),
                if (value.enabled)
                  Row(
                    children: [
                      Expanded(
                        child: _TimeButton(
                          label: 'Ouverture',
                          time: value.open,
                          onTap: () => _pickTime(day.key, true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TimeButton(
                          label: 'Fermeture',
                          time: value.close,
                          onTap: () => _pickTime(day.key, false),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.stroke),
        foregroundColor: AppColors.textPrimary,
      ),
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          Text(
            time,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayConfig {
  const _DayConfig(this.key, this.label);

  final String key;
  final String label;
}

class _DayValue {
  const _DayValue({
    this.enabled = false,
    this.open = '18:00',
    this.close = '23:00',
  });

  final bool enabled;
  final String open;
  final String close;
}
