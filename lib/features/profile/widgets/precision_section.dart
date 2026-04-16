import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/network/api_providers.dart';
import '../../match/widgets/dartboard_input_stats.dart';
import '../../../shared/models/dartboard_heatmap_models.dart';
import '../data/profile_service.dart';

enum PrecisionPeriodMode { month, year, all }

class PrecisionSection extends ConsumerStatefulWidget {
  const PrecisionSection({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<PrecisionSection> createState() => _PrecisionSectionState();
}

class _PrecisionSectionState extends ConsumerState<PrecisionSection> {
  static const List<String> _monthLabels = <String>[
    'Janvier',
    'Fevrier',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Aout',
    'Septembre',
    'Octobre',
    'Novembre',
    'Decembre',
  ];

  DartboardHeatmapPeriods _periods = const DartboardHeatmapPeriods();
  DartboardHeatmapData? _heatmap;
  PrecisionPeriodMode _mode = PrecisionPeriodMode.all;
  int? _selectedYear;
  int? _selectedMonth;
  bool _isLoadingPeriods = true;
  bool _isLoadingHeatmap = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPeriods();
  }

  @override
  void didUpdateWidget(covariant PrecisionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadPeriods();
    }
  }

  Future<void> _loadPeriods() async {
    setState(() {
      _isLoadingPeriods = true;
      _error = null;
      _heatmap = null;
    });

    try {
      final service = ProfileService(ref.read(apiClientProvider));
      final periods = await service.fetchDartboardPeriods(
        userId: widget.userId,
      );
      final latest = periods.years.isNotEmpty ? periods.years.first : null;
      final initialMode = latest == null
          ? PrecisionPeriodMode.all
          : (latest.months.isNotEmpty
                ? PrecisionPeriodMode.month
                : PrecisionPeriodMode.year);

      setState(() {
        _periods = periods;
        _mode = initialMode;
        _selectedYear = latest?.year;
        _selectedMonth = latest != null && latest.months.isNotEmpty
            ? latest.months.last
            : null;
        _isLoadingPeriods = false;
      });

      await _loadHeatmap();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _periods = const DartboardHeatmapPeriods();
        _isLoadingPeriods = false;
        _error = 'Impossible de charger les periodes de precision.';
      });
    }
  }

  Future<void> _loadHeatmap() async {
    if (_mode == PrecisionPeriodMode.month &&
        (_selectedYear == null || _selectedMonth == null)) {
      return;
    }
    if (_mode == PrecisionPeriodMode.year && _selectedYear == null) {
      return;
    }

    setState(() {
      _isLoadingHeatmap = true;
      _error = null;
    });

    try {
      final service = ProfileService(ref.read(apiClientProvider));
      final heatmap = await service.fetchDartboardHeatmap(
        userId: widget.userId,
        period: _mode.name,
        year: _selectedYear,
        month: _selectedMonth,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _heatmap = heatmap;
        _isLoadingHeatmap = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingHeatmap = false;
        _error = 'Impossible de charger la heatmap de precision.';
      });
    }
  }

  List<int> get _availableYears =>
      _periods.years.map((entry) => entry.year).toList(growable: false);

  List<int> get _availableMonths {
    if (_selectedYear == null) {
      return const <int>[];
    }
    return _findYearEntry(_selectedYear)?.months ?? const <int>[];
  }

  DartboardHeatmapYear? _findYearEntry(int? year) {
    if (year == null) {
      return null;
    }
    for (final entry in _periods.years) {
      if (entry.year == year) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _updateMode(PrecisionPeriodMode mode) async {
    final years = _availableYears;
    final fallbackYear =
        _selectedYear ?? (years.isNotEmpty ? years.first : null);
    final fallbackMonths =
        _findYearEntry(fallbackYear)?.months ?? const <int>[];

    setState(() {
      _mode = mode;
      _selectedYear = fallbackYear;
      _selectedMonth =
          mode == PrecisionPeriodMode.month && fallbackMonths.isNotEmpty
          ? fallbackMonths.last
          : null;
    });

    await _loadHeatmap();
  }

  Future<void> _updateYear(int? year) async {
    if (year == null) {
      return;
    }
    final months = _findYearEntry(year)?.months ?? const <int>[];
    setState(() {
      _selectedYear = year;
      if (_mode == PrecisionPeriodMode.month) {
        _selectedMonth = months.isNotEmpty ? months.last : null;
      }
    });
    await _loadHeatmap();
  }

  Future<void> _updateMonth(int? month) async {
    if (month == null) {
      return;
    }
    setState(() {
      _selectedMonth = month;
    });
    await _loadHeatmap();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Precision',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Uniquement les flechettes avec position sur la cible sont prises en compte.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            if (_isLoadingPeriods)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else ...[
              _buildControls(),
              const SizedBox(height: 14),
              if (_isLoadingHeatmap)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                DartboardInputStats(
                  hits: _heatmap?.hits ?? const <DartboardHeatHit>[],
                  subtitle: _heatmap == null
                      ? null
                      : '${_heatmap!.totalHits} flechettes positionnees',
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<PrecisionPeriodMode>(
            segments: const [
              ButtonSegment(
                value: PrecisionPeriodMode.month,
                label: Text('Mois'),
              ),
              ButtonSegment(
                value: PrecisionPeriodMode.year,
                label: Text('Annee'),
              ),
              ButtonSegment(
                value: PrecisionPeriodMode.all,
                label: Text('Tout'),
              ),
            ],
            selected: <PrecisionPeriodMode>{_mode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              final selected = selection.first;
              if (selected == PrecisionPeriodMode.month && !_periods.hasData) {
                return;
              }
              if (selected == PrecisionPeriodMode.year && !_periods.hasData) {
                return;
              }
              _updateMode(selected);
            },
          ),
        ),
        if (_mode != PrecisionPeriodMode.all) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SelectorField<int>(
                  label: 'Annee',
                  value: _selectedYear,
                  items: _availableYears,
                  itemLabel: (year) => '$year',
                  onChanged: _updateYear,
                ),
              ),
              if (_mode == PrecisionPeriodMode.month) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _SelectorField<int>(
                    label: 'Mois',
                    value: _selectedMonth,
                    items: _availableMonths,
                    itemLabel: (month) => _monthLabels[month - 1],
                    onChanged: _updateMonth,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _SelectorField<T> extends StatelessWidget {
  const _SelectorField({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.stroke),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          dropdownColor: AppColors.surface,
          value: value,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemLabel(item),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: items.isEmpty ? null : onChanged,
        ),
      ),
    );
  }
}
