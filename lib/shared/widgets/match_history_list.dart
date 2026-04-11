import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/app_colors.dart';
import '../../core/config/translation_service.dart';
import '../models/match_history_summary.dart';
import 'player_avatar.dart';

class MatchHistoryList extends StatelessWidget {
  const MatchHistoryList({
    super.key,
    required this.matches,
    this.maxItems,
    this.showLoadMore = false,
    this.onLoadMore,
    this.showViewAll = false,
    this.onViewAll,
    this.onMatchTap,
  });

  final List<MatchHistorySummary> matches;
  final int? maxItems;
  final bool showLoadMore;
  final VoidCallback? onLoadMore;
  final bool showViewAll;
  final VoidCallback? onViewAll;
  final ValueChanged<String>? onMatchTap;

  @override
  Widget build(BuildContext context) {
    final visibleMatches = maxItems == null
        ? matches
        : matches.take(maxItems!).toList(growable: false);

    if (visibleMatches.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Text(
          t(
            'SCREEN.PROFILE.HISTORY_EMPTY',
            fallback: 'Aucun match a afficher pour le moment.',
          ),
          style: GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        ...visibleMatches.map(
          (match) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onMatchTap == null
                  ? null
                  : () => onMatchTap!.call(match.matchId),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Row(
                  children: [
                    PlayerAvatar(
                      imageUrl: match.opponentAvatarUrl,
                      name: match.opponentName,
                      size: 36,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.opponentName,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${match.mode} · ${_formatRelativeTime(match.playedAt)}',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppColors.textHint,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      match.setsScore,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: match.won
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        match.won ? 'V' : 'D',
                        style: GoogleFonts.manrope(
                          color: match.won
                              ? AppColors.success
                              : AppColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showLoadMore && onLoadMore != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ElevatedButton(
              onPressed: onLoadMore,
              child: Text(t('COMMON.SEE_MORE', fallback: 'Voir plus')),
            ),
          ),
        if (showViewAll && onViewAll != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton(
              onPressed: onViewAll,
              child: Text(t('SCREEN.HOME.VIEW_ALL', fallback: 'Voir tout')),
            ),
          ),
      ],
    );
  }

  static String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inHours < 1) {
      return t('COMMON.TIME.NOW', fallback: 'A l\'instant');
    }
    if (diff.inHours < 24) {
      return '${t('COMMON.TIME.AGO', fallback: 'Il y a')} ${diff.inHours}h';
    }
    if (diff.inDays == 1) {
      return t('COMMON.TIME.YESTERDAY', fallback: 'Hier');
    }
    return '${t('COMMON.TIME.AGO', fallback: 'Il y a')} ${diff.inDays}j';
  }
}
