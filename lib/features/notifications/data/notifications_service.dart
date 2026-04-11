import '../../../core/network/api_client.dart';

class NotificationsService {
  const NotificationsService(this._api);

  final ApiClient _api;

  Future<int> unreadCount() async {
    final response = await _api.get<Map<String, dynamic>>('/notifications/unread-count');
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
