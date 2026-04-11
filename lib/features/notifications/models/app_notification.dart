class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  AppNotification copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];

    return AppNotification(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'system').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      isRead: json['is_read'] == true,
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      data: rawData is Map<String, dynamic>
          ? rawData
          : (rawData is Map ? Map<String, dynamic>.from(rawData) : null),
    );
  }
}
