import '../../../core/network/api_client.dart';
import '../models/app_notification.dart';

class NotificationsService {
  const NotificationsService(this._api);

  final ApiClient _api;

  Future<List<AppNotification>> fetchNotifications({int limit = 50}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: {'limit': '$limit'},
    );

    final body = response.data ?? const <String, dynamic>{};
    final dynamic payload = body['data'] ?? body;

    if (payload is! List) {
      return const <AppNotification>[];
    }

    return payload
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .map(AppNotification.fromJson)
        .toList(growable: false);
  }

  Future<void> markAsRead(String notificationId) async {
    await _api.patch<Map<String, dynamic>>(
      '/notifications/$notificationId/read',
    );
  }

  Future<void> markAllAsRead() async {
    await _api.patch<Map<String, dynamic>>('/notifications/read-all');
  }

  Future<int> unreadCount() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/notifications/unread-count',
    );
    final body = response.data ?? const <String, dynamic>{};
    final data = body['data'];

    if (data is int) {
      return data;
    }
    if (data is num) {
      return data.toInt();
    }
    if (data is Map<String, dynamic>) {
      final value = data['count'] ?? data['unread_count'];
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
    }
    if (body['count'] is num) {
      return (body['count'] as num).toInt();
    }
    return 0;
  }
}
