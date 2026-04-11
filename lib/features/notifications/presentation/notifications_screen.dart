import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/config/translation_service.dart';
import '../controller/notifications_controller.dart';
import '../models/app_notification.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          t('SCREEN.NOTIFICATIONS.TITLE', fallback: 'Notifications'),
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: state.unreadCount > 0
                ? () => ref
                      .read(notificationsStateProvider.notifier)
                      .markAllAsRead()
                : null,
            child: Text(
              t('SCREEN.NOTIFICATIONS.MARK_ALL_READ', fallback: 'Tout lire'),
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                color: state.unreadCount > 0
                    ? AppColors.primary
                    : AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: RefreshIndicator(
          onRefresh: () => ref
              .read(notificationsStateProvider.notifier)
              .refresh(withLoader: false),
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 120),
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 64,
                      color: AppColors.textHint.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t(
                        'SCREEN.NOTIFICATIONS.EMPTY',
                        fallback: 'Aucune notification pour le moment.',
                      ),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                  itemCount: state.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return _NotificationCard(item: item);
                  },
                ),
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        ref.read(notificationsStateProvider.notifier).markOneAsRead(item.id);
        final route = _matchReportRoute(item);
        if (route != null) {
          context.push(route);
        }
      },
      child: Ink(
        decoration: BoxDecoration(
          color: item.isRead
              ? AppColors.card.withValues(alpha: 0.75)
              : AppColors.card.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isRead
                ? AppColors.stroke
                : AppColors.primary.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _typeColor(item.type).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _typeIcon(item.type),
                  size: 18,
                  color: _typeColor(item.type),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.trim().isEmpty
                          ? _fallbackTitle(item.type)
                          : item.title,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (item.body.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.body,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _relativeDate(item.createdAt),
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.isRead)
                IconButton(
                  icon: const Icon(Icons.done_rounded, size: 18),
                  color: AppColors.primary,
                  onPressed: () => ref
                      .read(notificationsStateProvider.notifier)
                      .markOneAsRead(item.id),
                  tooltip: t(
                    'SCREEN.NOTIFICATIONS.MARK_READ',
                    fallback: 'Marquer lu',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _matchReportRoute(AppNotification notification) {
    final data = notification.data;
    if (data == null) {
      return null;
    }

    final rawMatchId = data['match_id'] ?? data['matchId'];
    if (rawMatchId is! String || rawMatchId.trim().isEmpty) {
      return null;
    }

    return AppRoutes.matchReport.replaceFirst(':id', rawMatchId);
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'match_invite':
        return AppColors.primary;
      case 'duel_request':
        return AppColors.secondary;
      case 'territory_update':
        return AppColors.warning;
      case 'club_invite':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'match_invite':
        return Icons.sports_martial_arts;
      case 'duel_request':
        return Icons.flash_on_rounded;
      case 'territory_update':
        return Icons.map_outlined;
      case 'club_invite':
        return Icons.groups_rounded;
      case 'tournament':
        return Icons.emoji_events_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  String _fallbackTitle(String type) {
    switch (type) {
      case 'match_invite':
        return t(
          'SCREEN.NOTIFICATIONS.MATCH_INVITE',
          fallback: 'Invitation de match',
        );
      case 'duel_request':
        return t('SCREEN.NOTIFICATIONS.DUEL_REQUEST', fallback: 'Nouveau duel');
      case 'territory_update':
        return t(
          'SCREEN.NOTIFICATIONS.TERRITORY',
          fallback: 'Territoire mis a jour',
        );
      case 'club_invite':
        return t(
          'SCREEN.NOTIFICATIONS.CLUB_INVITE',
          fallback: 'Invitation de club',
        );
      default:
        return t(
          'SCREEN.NOTIFICATIONS.DEFAULT_TITLE',
          fallback: 'Notification',
        );
    }
  }

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) {
      return t('SCREEN.NOTIFICATIONS.NOW', fallback: 'A l\'instant');
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} h';
    }
    return '${diff.inDays} j';
  }
}
