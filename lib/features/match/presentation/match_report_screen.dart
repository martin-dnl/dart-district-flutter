import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/config/translation_service.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/player_avatar.dart';
import '../../../shared/widgets/section_header.dart';
import '../controller/match_report_provider.dart';
import '../models/match_model.dart';
import '../models/match_report_data.dart';
import '../widgets/dartboard_input_stats.dart';
import '../../social/controller/social_feed_controller.dart';

class MatchReportScreen extends ConsumerWidget {
  const MatchReportScreen({super.key, required this.matchId, this.extra});

  final String matchId;
  final Object? extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    MatchReportData? localReport;
    if (extra is MatchModel) {
      localReport = MatchReportData.fromLocalMatch(extra as MatchModel);
    }

    if (localReport != null) {
      return _MatchReportView(data: localReport);
    }

    final reportAsync = ref.watch(matchReportProvider(matchId));
    return reportAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(t('SCREEN.MATCH.REPORT.TITLE', fallback: 'Rapport de match')),
        ),
        body: Center(
          child: Text(
            t(
              'SCREEN.MATCH.REPORT.LOAD_ERROR',
              fallback: 'Impossible de charger le rapport.',
            ),
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
      data: (data) => _MatchReportView(data: data),
    );
  }
}

class _MatchReportView extends ConsumerWidget {
  const _MatchReportView({required this.data});

  final MatchReportData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isP1Winner = data.winnerIndex == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t('SCREEN.MATCH.REPORT.TITLE', fallback: 'Rapport de match')),
        backgroundColor: AppColors.background,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            GlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            PlayerAvatar(
                              imageUrl: data.player1.avatarUrl,
                              name: data.player1.name,
                              size: 48,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              data.player1.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            data.setsScore,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isP1Winner
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isP1Winner
                                  ? t('SCREEN.MATCH.REPORT.VICTORY', fallback: 'VICTOIRE')
                                  : t('SCREEN.MATCH.REPORT.DEFEAT', fallback: 'DEFAITE'),
                              style: TextStyle(
                                color: isP1Winner
                                    ? AppColors.success
                                    : AppColors.error,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            PlayerAvatar(
                              imageUrl: data.player2.avatarUrl,
                              name: data.player2.name,
                              size: 48,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              data.player2.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(
                      t('SCREEN.MATCH.REPORT.STATS', fallback: 'Statistiques'),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatRow(
                    label: t('SCREEN.MATCH.REPORT.AVERAGE', fallback: 'Moyenne'),
                    valueP1: data.player1.average.toStringAsFixed(1),
                    valueP2: data.player2.average.toStringAsFixed(1),
                  ),
                  _StatRow(
                    label: t('SCREEN.MATCH.REPORT.BEST_LEG', fallback: 'Best Leg'),
                    valueP1: data.player1.bestLegAvg.toStringAsFixed(1),
                    valueP2: data.player2.bestLegAvg.toStringAsFixed(1),
                  ),
                  _StatRow(
                    label: t('SCREEN.MATCH.REPORT.CHECKOUT_RATE', fallback: 'Checkout %'),
                    valueP1: '${data.player1.checkoutRate.toStringAsFixed(1)}%',
                    valueP2: '${data.player2.checkoutRate.toStringAsFixed(1)}%',
                  ),
                  _StatRow(
                    label: t('SCREEN.MATCH.REPORT.SCORE_180', fallback: '180s'),
                    valueP1: '${data.player1.count180}',
                    valueP2: '${data.player2.count180}',
                  ),
                  _StatRow(
                    label: t('SCREEN.MATCH.REPORT.SCORE_140_PLUS', fallback: '140+'),
                    valueP1: '${data.player1.count140Plus}',
                    valueP2: '${data.player2.count140Plus}',
                  ),
                  _StatRow(
                    label: t('SCREEN.MATCH.REPORT.SCORE_100_PLUS', fallback: '100+'),
                    valueP1: '${data.player1.count100Plus}',
                    valueP2: '${data.player2.count100Plus}',
                  ),
                  _StatRow(
                    label: t(
                      'SCREEN.MATCH.REPORT.DOUBLES_ATTEMPTED',
                      fallback: 'Doubles tentes',
                    ),
                    valueP1: '${data.player1.doublesAttempted}',
                    valueP2: '${data.player2.doublesAttempted}',
                    lowerIsBetter: true,
                  ),
                  _StatRow(
                    label: t(
                      'SCREEN.MATCH.REPORT.DOUBLES_HIT',
                      fallback: 'Doubles reussis',
                    ),
                    valueP1: '${data.player1.doublesHit}',
                    valueP2: '${data.player2.doublesHit}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SectionHeader(
              title: t('SCREEN.MATCH.REPORT.PRECISION', fallback: 'Precision'),
            ),
            _MatchPrecisionSection(data: data),
            const SizedBox(height: 10),
            SectionHeader(
              title: t('SCREEN.MATCH.REPORT.TIMELINE', fallback: 'Timeline'),
            ),
            GlassCard(
              child: Column(
                children: data.timeline.map((leg) {
                  final winnerName =
                      leg.winnerName ??
                      (leg.winnerIndex == 0
                          ? data.player1.name
                          : data.player2.name);
                    final text = leg.isAbandonEvent
                      ? '${t('SCREEN.MATCH.REPORT.SURRENDER_OF', fallback: 'Abandon de')} $winnerName'
                      : 'Set ${leg.setNumber} - Leg ${leg.legNumber} : $winnerName';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            text,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final description = await _askShareDescription(context);
                if (description == null) {
                  return;
                }

                final ok = await ref
                    .read(socialFeedControllerProvider.notifier)
                    .shareMatchReport(data, description);
                if (!context.mounted) {
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? t(
                              'SCREEN.MATCH.REPORT.SHARED_SUCCESS',
                              fallback: 'Partage publie dans votre fil.',
                            )
                          : t(
                              'SCREEN.MATCH.REPORT.SHARED_FAILED',
                              fallback: 'Impossible de partager ce match.',
                            ),
                    ),
                    action: ok
                        ? SnackBarAction(
                            label: t('SCREEN.MATCH.REPORT.OPEN_FEED', fallback: 'Voir fil'),
                            onPressed: () => context.push(AppRoutes.socialFeed),
                          )
                        : null,
                  ),
                );
              },
              icon: const Icon(Icons.share_outlined),
              label: Text(t('COMMON.SHARE', fallback: 'Partager')),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askShareDescription(BuildContext context) {
    final controller = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              6,
              16,
              12 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(
                    'SCREEN.MATCH.REPORT.SHARE_MODAL_TITLE',
                    fallback: 'Partager cette partie',
                  ),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t(
                    'SCREEN.MATCH.REPORT.SHARE_MODAL_HINT',
                    fallback: 'Ajoutez un petit commentaire pour vos amis.',
                  ),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  minLines: 3,
                  maxLength: 220,
                  decoration: InputDecoration(
                    hintText: t(
                      'SCREEN.MATCH.REPORT.SHARE_MODAL_PLACEHOLDER',
                      fallback: 'Ex: Gros finish sous pression !',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(t('COMMON.CANCEL', fallback: 'Annuler')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                        child: Text(t('COMMON.SHARE', fallback: 'Partager')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MatchPrecisionSection extends StatelessWidget {
  const _MatchPrecisionSection({required this.data});

  final MatchReportData data;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vertical = constraints.maxWidth < 760;
          return Column(
            children: [
              if (vertical)
                Column(
                  children: [
                    _playerHeatmap(data.player1),
                    const SizedBox(height: 12),
                    _playerHeatmap(data.player2),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _playerHeatmap(data.player1)),
                    const SizedBox(width: 12),
                    Expanded(child: _playerHeatmap(data.player2)),
                  ],
                ),
              const SizedBox(height: 12),
              Text(
                t(
                  'SCREEN.MATCH.REPORT.PRECISION_HINT',
                  fallback:
                      'Seules les flechettes jouees avec une position sur la cible sont affichees.',
                ),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _playerHeatmap(PlayerReportStats player) {
    return DartboardInputStats(
      hits: player.dartPositions,
      title: player.name,
      subtitle:
          '${player.dartPositions.length} ${t('SCREEN.MATCH.REPORT.DARTS_POSITIONED', fallback: 'flechettes positionnees')}',
      showLegend: false,
      emptyMessage:
          '${t('SCREEN.MATCH.REPORT.NO_DART_POSITIONED_FOR', fallback: 'Aucune flechette positionnee pour')} ${player.name}.',
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.valueP1,
    required this.valueP2,
    this.lowerIsBetter = false,
  });

  final String label;
  final String valueP1;
  final String valueP2;
  final bool lowerIsBetter;

  @override
  Widget build(BuildContext context) {
    final p1 = _parse(valueP1);
    final p2 = _parse(valueP2);
    final p1Better = lowerIsBetter ? p1 < p2 : p1 > p2;
    final p2Better = lowerIsBetter ? p2 < p1 : p2 > p1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              valueP1,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: p1Better ? AppColors.primary : AppColors.textPrimary,
                fontWeight: p1Better ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              valueP2,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: p2Better ? AppColors.primary : AppColors.textPrimary,
                fontWeight: p2Better ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _parse(String value) {
    final normalized = value.replaceAll('%', '').replaceAll(',', '.').trim();
    return double.tryParse(normalized) ?? 0;
  }
}
