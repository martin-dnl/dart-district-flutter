import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/translation_service.dart';
import '../../../shared/widgets/glass_card.dart';
import '../controller/profile_controller.dart';

class EloChart extends StatelessWidget {
  const EloChart({
    super.key,
    required this.points,
    required this.mode,
    required this.periodLabel,
    required this.offset,
    required this.isLoading,
    required this.onModeChanged,
    required this.onShiftOffset,
  });

  final List<EloPeriodPoint> points;
  final EloPeriodMode mode;
  final String periodLabel;
  final int offset;
  final bool isLoading;
  final ValueChanged<EloPeriodMode> onModeChanged;
  final ValueChanged<int> onShiftOffset;

  static const double _loadingHeight = 250;
  static const double _emptyHeight = 280;
  static const double _chartHeight = 300;

  String _modeLabel(EloPeriodMode value) {
    switch (value) {
      case EloPeriodMode.week:
        return t('SCREEN.PROFILE.WEEK', fallback: 'Semaine');
      case EloPeriodMode.month:
        return t('SCREEN.PROFILE.MONTH', fallback: 'Mois');
      case EloPeriodMode.year:
        return t('SCREEN.PROFILE.YEAR', fallback: 'Annee');
    }
  }

  String _compactLabel(String isoLike) {
    if (mode == EloPeriodMode.year && isoLike.length >= 7) {
      return isoLike.substring(2);
    }
    if (isoLike.length >= 10) {
      return '${isoLike.substring(8, 10)}/${isoLike.substring(5, 7)}';
    }
    return isoLike;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const GlassCard(
        child: SizedBox(
          height: _loadingHeight,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (points.isEmpty) {
      return GlassCard(
        child: SizedBox(
          height: _emptyHeight,
          child: Column(
            children: [
              _ChartToolbar(
                mode: mode,
                periodLabel: periodLabel,
                onModeChanged: onModeChanged,
                modeLabelBuilder: _modeLabel,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    t(
                      'SCREEN.PROFILE.NO_DATA',
                      fallback: 'Pas encore de donnees',
                    ),
                    style: const TextStyle(color: AppColors.textHint),
                  ),
                ),
              ),
              _PeriodShiftRow(offset: offset, onShiftOffset: onShiftOffset),
            ],
          ),
        ),
      );
    }

    final values = points.map((point) => point.elo).toList(growable: false);
    final spots = values
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();

    final minY = (values.reduce((a, b) => a < b ? a : b) - 40).toDouble();
    final maxY = (values.reduce((a, b) => a > b ? a : b) + 40).toDouble();

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: SizedBox(
        height: _chartHeight,
        child: Column(
          children: [
            _ChartToolbar(
              mode: mode,
              periodLabel: periodLabel,
              onModeChanged: onModeChanged,
              modeLabelBuilder: _modeLabel,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 40,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: AppColors.surfaceLight, strokeWidth: 0.5),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: (values.length / 4)
                            .clamp(1, values.length)
                            .toDouble(),
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            _compactLabel(points[index].label),
                            style: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (values.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: AppColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: index == values.length - 1 ? 5 : 3,
                            color: index == values.length - 1
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.5),
                            strokeWidth: 0,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) =>
                          touchedSpots.map((spot) {
                            final index = spot.x.round();
                            final label = index >= 0 && index < points.length
                                ? points[index].label
                                : '';
                            return LineTooltipItem(
                              'ELO ${spot.y.toInt()}\n$label',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _PeriodShiftRow(offset: offset, onShiftOffset: onShiftOffset),
          ],
        ),
      ),
    );
  }
}

class _ChartToolbar extends StatelessWidget {
  const _ChartToolbar({
    required this.mode,
    required this.periodLabel,
    required this.onModeChanged,
    required this.modeLabelBuilder,
  });

  final EloPeriodMode mode;
  final String periodLabel;
  final ValueChanged<EloPeriodMode> onModeChanged;
  final String Function(EloPeriodMode) modeLabelBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<EloPeriodMode>(
            segments: EloPeriodMode.values
                .map(
                  (value) => ButtonSegment<EloPeriodMode>(
                    value: value,
                    label: Text(modeLabelBuilder(value)),
                  ),
                )
                .toList(growable: false),
            selected: <EloPeriodMode>{mode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              final selected = selection.first;
              if (selected == mode) {
                return;
              }
              onModeChanged(selected);
            },
          ),
        ),
        if (periodLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              periodLabel,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _PeriodShiftRow extends StatelessWidget {
  const _PeriodShiftRow({required this.offset, required this.onShiftOffset});

  final int offset;
  final ValueChanged<int> onShiftOffset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.stroke),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => onShiftOffset(offset + 1),
            icon: const Icon(Icons.chevron_left),
            tooltip: t(
              'SCREEN.PROFILE.PREVIOUS_PERIOD',
              fallback: 'Periode precedente',
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.stroke),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: offset > 0 ? () => onShiftOffset(offset - 1) : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: t(
              'SCREEN.PROFILE.NEXT_PERIOD',
              fallback: 'Periode suivante',
            ),
          ),
        ],
      ),
    );
  }
}
