import '../../../core/network/api_client.dart';
import '../models/contact_models.dart';

class ContactsRepository {
  ContactsRepository(this._api);

  final ApiClient _api;

  Future<List<ContactModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      return const [];
    }

    final response = await _api.get<Map<String, dynamic>>(
      '/users/search',
      queryParameters: {'q': query.trim(), 'limit': 20},
    );

    final data = _unwrap(response.data);
    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(ContactModel.fromApi)
        .toList();
  }

  Future<List<ContactModel>> fetchFriends() async {
    final response = await _api.get<Map<String, dynamic>>('/contacts/friends');
    final data = _unwrap(response.data);
    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(ContactModel.fromApi)
        .toList();
  }

  Future<ContactModel> addFriend(String friendId) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/contacts/friends',
      data: {'friend_id': friendId},
    );
    final data = _unwrap(response.data);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid friend payload');
    }
    return ContactModel.fromApi(data);
  }

  Future<String> sendFriendRequest(String receiverId) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/contacts/requests',
      data: {'receiver_id': receiverId},
    );
    final data = _unwrap(response.data);
    if (data is! Map<String, dynamic>) {
      return 'pending';
    }
    return (data['status'] ?? 'pending').toString();
  }

  Future<List<FriendRequestModel>> fetchIncomingRequests() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/contacts/requests/incoming',
    );
    final data = _unwrap(response.data);
    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map((json) => FriendRequestModel.fromApi(json, isIncoming: true))
        .toList();
  }

  Future<List<FriendRequestModel>> fetchOutgoingRequests() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/contacts/requests/outgoing',
    );
    final data = _unwrap(response.data);
    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map((json) => FriendRequestModel.fromApi(json, isIncoming: false))
        .toList();
  }

  Future<void> acceptRequest(String requestId) async {
    await _api.post<Map<String, dynamic>>(
      '/contacts/requests/$requestId/accept',
    );
  }

  Future<void> rejectRequest(String requestId) async {
    await _api.post<Map<String, dynamic>>(
      '/contacts/requests/$requestId/reject',
    );
  }

  Future<void> blockUser(String userId) async {
    await _api.post<Map<String, dynamic>>('/contacts/block/$userId');
  }

  Future<List<ContactMessage>> fetchConversation(
    String contactId, {
    int limit = 100,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/contacts/messages/$contactId',
      queryParameters: {'limit': limit},
    );
    final data = _unwrap(response.data);
    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(ContactMessage.fromSocket)
        .toList();
  }

  Future<Map<String, int>> fetchUnreadByContact() async {
    final response = await _api.get<Map<String, dynamic>>('/contacts/unread');
    final data = _unwrap(response.data);
    if (data is! Map<String, dynamic>) {
      return const <String, int>{};
    }

    final byUser = data['by_user'];
    if (byUser is! Map<String, dynamic>) {
      return const <String, int>{};
    }

    return byUser.map((key, value) => MapEntry(key, _toInt(value)));
  }

  Future<void> markConversationRead(String contactId) async {
    await _api.post<Map<String, dynamic>>('/contacts/messages/$contactId/read');
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  dynamic _unwrap(Map<String, dynamic>? body) {
    if (body == null) return null;
    return body['data'] ?? body;
  }
}
