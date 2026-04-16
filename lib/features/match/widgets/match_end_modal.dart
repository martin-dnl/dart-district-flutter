import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/network/api_providers.dart';
import '../../../shared/widgets/neon_modal.dart';
import '../../../shared/widgets/animated_counter_text.dart';

class MatchEndResultDialog extends ConsumerStatefulWidget {
  const MatchEndResultDialog({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<MatchEndResultDialog> createState() =>
      _MatchEndResultDialogState();
}

class _MatchEndResultDialogState extends ConsumerState<MatchEndResultDialog> {
  late final Future<_MatchResultSummary?> _summaryFuture;

  bool _showElo = false;
  bool _showTerritoryPoints = false;
  bool _showActions = false;
  bool _didHaptic = false;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
    _summaryFuture.then(_startRevealSequence);
  }

  Future<_MatchResultSummary?> _loadSummary() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get<Map<String, dynamic>>(
        '/matches/${widget.matchId}/result-summary',
      );
      final raw = response.data ?? const <String, dynamic>{};
      final data = raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
      return _MatchResultSummary.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  void _startRevealSequence(_MatchResultSummary? summary) {
    if (!mounted) {
      return;
    }

    if (summary == null) {
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) {
          return;
        }
        setState(() => _showActions = true);
      });
      return;
    }

    final showEloSection = summary.isRanked;
    final showTerritorySection =
        summary.isRanked &&
        summary.isTerritorial &&
        summary.territoryPointsGained > 0;

    if (showEloSection) {
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) {
          return;
        }
        setState(() => _showElo = true);
      });

      Future<void>.delayed(const Duration(milliseconds: 2000), () {
        if (!mounted || _didHaptic) {
          return;
        }
        _didHaptic = true;
        HapticFeedback.mediumImpact();
      });
    }

    if (showTerritorySection) {
      Future<void>.delayed(const Duration(milliseconds: 2100), () {
        if (!mounted) {
          return;
        }
        setState(() => _showTerritoryPoints = true);
      });
    }

    final actionsDelay = showTerritorySection
        ? const Duration(milliseconds: 3200)
        : (showEloSection
              ? const Duration(milliseconds: 2200)
              : const Duration(milliseconds: 700));

    Future<void>.delayed(actionsDelay, () {
      if (!mounted) {
        return;
      }
      setState(() => _showActions = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: NeonModalContainer(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          child: FutureBuilder<_MatchResultSummary?>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              final summary = snapshot.data;

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              if (summary == null) {
                return SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Match termine',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Consulter le rapport de match ? ',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      _ActionRow(
                        visible: _showActions,
                        onLater: () => Navigator.pop(context, false),
                        onOpenReport: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                );
              }

              final eloColor = summary.eloDelta > 0
                  ? AppColors.primary
                  : (summary.eloDelta < 0
                        ? Colors.redAccent
                        : AppColors.textSecondary);
              final showTerritorySection =
                  summary.isRanked &&
                  summary.isTerritorial &&
                  summary.territoryPointsGained > 0;

              return SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Match termine',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.92, end: 1),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Text(
                        summary.isWinner ? 'Victoire' : 'Defaite',
                        style: TextStyle(
                          color: summary.isWinner
                              ? AppColors.primary
                              : Colors.redAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (summary.isRanked)
                      AnimatedOpacity(
                        opacity: _showElo ? 1 : 0,
                        duration: const Duration(milliseconds: 260),
                        child: IgnorePointer(
                          ignoring: !_showElo,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ELO',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedCounterText(
                                from: summary.eloBefore,
                                to: summary.eloAfter,
                                duration: const Duration(milliseconds: 1500),
                                style: TextStyle(
                                  color: eloColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    summary.eloDelta >= 0
                                        ? Icons.trending_up
                                        : Icons.trending_down,
                                    size: 16,
                                    color: eloColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${summary.eloDelta >= 0 ? '+' : ''}${summary.eloDelta}',
                                    style: TextStyle(
                                      color: eloColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (showTerritorySection) ...[
                      const SizedBox(height: 12),
                      AnimatedOpacity(
                        opacity: _showTerritoryPoints ? 1 : 0,
                        duration: const Duration(milliseconds: 260),
                        child: IgnorePointer(
                          ignoring: !_showTerritoryPoints,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Points club${summary.territoryName == null ? '' : ' - ${summary.territoryName}'}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedCounterText(
                                from: 0,
                                to: summary.territoryPointsGained,
                                duration: const Duration(milliseconds: 1000),
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                                prefix: '+',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _ActionRow(
                      visible: _showActions,
                      onLater: () => Navigator.pop(context, false),
                      onOpenReport: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.visible,
    required this.onLater,
    required this.onOpenReport,
  });

  final bool visible;
  final VoidCallback onLater;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 280),
      child: IgnorePointer(
        ignoring: !visible,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: onLater, child: const Text('Plus tard')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onOpenReport,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
              ),
              child: const Text('Voir le rapport'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchResultSummary {
  const _MatchResultSummary({
    required this.isWinner,
    required this.eloBefore,
    required this.eloAfter,
    required this.eloDelta,
    required this.territoryPointsGained,
    required this.territoryName,
    required this.isRanked,
    required this.isTerritorial,
  });

  final bool isWinner;
  final int eloBefore;
  final int eloAfter;
  final int eloDelta;
  final int territoryPointsGained;
  final String? territoryName;
  final bool isRanked;
  final bool isTerritorial;

  factory _MatchResultSummary.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    return _MatchResultSummary(
      isWinner: json['is_winner'] == true,
      eloBefore: asInt(json['elo_before']),
      eloAfter: asInt(json['elo_after']),
      eloDelta: asInt(json['elo_delta']),
      territoryPointsGained: asInt(json['territory_points_gained']),
      territoryName: json['territory_name']?.toString(),
      isRanked: json['is_ranked'] == true,
      isTerritorial: json['is_territorial'] == true,
    );
  }
}
