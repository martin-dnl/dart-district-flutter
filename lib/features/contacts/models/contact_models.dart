class ContactModel {
  const ContactModel({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.elo = 1000,
    this.unreadCount = 0,
    this.clubId,
  });

  final String id;
  final String username;
  final String? avatarUrl;
  final int elo;
  final int unreadCount;
  final String? clubId;

  factory ContactModel.fromApi(Map<String, dynamic> json) {
    final memberships = json['club_memberships'] as List<dynamic>?;
    final firstMembership = memberships != null && memberships.isNotEmpty
        ? memberships.first as Map<String, dynamic>
        : null;
    final club = firstMembership?['club'] as Map<String, dynamic>?;

    return ContactModel(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? 'Joueur').toString(),
      avatarUrl: json['avatar_url'] as String?,
      elo: (json['elo'] as num?)?.toInt() ?? 1000,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      clubId: (json['club_id'] ?? club?['id'])?.toString(),
    );
  }

  ContactModel copyWith({
    String? id,
    String? username,
    String? avatarUrl,
    int? elo,
    int? unreadCount,
    String? clubId,
  }) {
    return ContactModel(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      elo: elo ?? this.elo,
      unreadCount: unreadCount ?? this.unreadCount,
      clubId: clubId ?? this.clubId,
    );
  }
}

class ContactMessage {
  const ContactMessage({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.content,
    required this.createdAt,
    this.readAt,
    this.isLocalEcho = false,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final String content;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isLocalEcho;

  factory ContactMessage.fromSocket(Map<String, dynamic> json) {
    return ContactMessage(
      id: (json['id'] ?? '').toString(),
      fromUserId: (json['from_user_id'] ?? '').toString(),
      toUserId: (json['to_user_id'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      readAt: DateTime.tryParse((json['read_at'] ?? '').toString()),
    );
  }

  ContactMessage copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    String? content,
    DateTime? createdAt,
    DateTime? readAt,
    bool? isLocalEcho,
  }) {
    return ContactMessage(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      isLocalEcho: isLocalEcho ?? this.isLocalEcho,
    );
  }
}

class FriendRequestModel {
  const FriendRequestModel({
    required this.id,
    required this.user,
    required this.createdAt,
    required this.isIncoming,
  });

  final String id;
  final ContactModel user;
  final DateTime createdAt;
  final bool isIncoming;

  factory FriendRequestModel.fromApi(
    Map<String, dynamic> json, {
    required bool isIncoming,
  }) {
    final userJson = isIncoming
        ? json['sender'] as Map<String, dynamic>?
        : json['receiver'] as Map<String, dynamic>?;

    return FriendRequestModel(
      id: (json['id'] ?? '').toString(),
      user: ContactModel.fromApi(userJson ?? const <String, dynamic>{}),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      isIncoming: isIncoming,
    );
  }
}
