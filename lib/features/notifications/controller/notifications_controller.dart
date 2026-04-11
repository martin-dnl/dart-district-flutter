import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../data/notifications_service.dart';

class NotificationsCountController extends StateNotifier<int> {
  NotificationsCountController(this._service) : super(0) {
    refresh();
  }

  final NotificationsService _service;

  Future<void> refresh() async {
    try {
      state = await _service.unreadCount();
    } catch (_) {
      state = 0;
    }
  }
}

final notificationsUnreadCountProvider =
    StateNotifierProvider<NotificationsCountController, int>((ref) {
  return NotificationsCountController(
    NotificationsService(ref.read(apiClientProvider)),
  );
});
