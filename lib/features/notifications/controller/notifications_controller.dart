import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../data/notifications_service.dart';
import '../models/app_notification.dart';

class NotificationsState {
  const NotificationsState({
    this.items = const <AppNotification>[],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  final List<AppNotification> items;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? unreadCount,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this._service)
    : super(const NotificationsState(isLoading: true)) {
    refresh();
  }

  final NotificationsService _service;

  Future<void> refresh({bool withLoader = false}) async {
    if (withLoader) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final results = await Future.wait([
        _service.unreadCount(),
        _service.fetchNotifications(limit: 50),
      ]);

      state = state.copyWith(
        unreadCount: results[0] as int,
        items: results[1] as List<AppNotification>,
        isLoading: false,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Impossible de charger les notifications.',
      );
    }
  }

  Future<void> markOneAsRead(String notificationId) async {
    final index = state.items.indexWhere((n) => n.id == notificationId);
    if (index < 0 || state.items[index].isRead) {
      return;
    }

    final updatedItems = [...state.items];
    updatedItems[index] = updatedItems[index].copyWith(isRead: true);

    state = state.copyWith(
      items: updatedItems,
      unreadCount: (state.unreadCount - 1).clamp(0, 9999),
    );

    try {
      await _service.markAsRead(notificationId);
    } catch (_) {
      await refresh();
    }
  }

  Future<void> markAllAsRead() async {
    final hadUnread = state.unreadCount > 0;
    if (!hadUnread) {
      return;
    }

    final updated = state.items
        .map((item) => item.isRead ? item : item.copyWith(isRead: true))
        .toList(growable: false);

    state = state.copyWith(items: updated, unreadCount: 0);

    try {
      await _service.markAllAsRead();
    } catch (_) {
      await refresh();
    }
  }
}

final notificationsStateProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
      return NotificationsController(
        NotificationsService(ref.read(apiClientProvider)),
      );
    });

final notificationsUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(
    notificationsStateProvider.select((state) => state.unreadCount),
  );
});
