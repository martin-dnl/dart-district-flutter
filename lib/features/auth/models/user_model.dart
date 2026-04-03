class UserModel {
  final String id;
  final String username;
  final String? email;
  final String? avatarUrl;
  final int elo;
  final String? clubId;
  final String? clubName;
  final bool isAdmin;
  final DateTime createdAt;
  final PlayerStats stats;

  const UserModel({
    required this.id,
    required this.username,
    this.email,
    this.avatarUrl,
    this.elo = 1000,
    this.clubId,
    this.clubName,
    this.isAdmin = false,
    required this.createdAt,
    this.stats = const PlayerStats(),
  });

  factory UserModel.guest() {
    return UserModel(
      id: 'guest',
      username: 'Invité',
      createdAt: DateTime.now(),
    );
  }

  /// Temporary placeholder for a new SSO user not yet registered in DB.
  factory UserModel.ssoPending({required String email, required String name}) {
    return UserModel(
      id: 'sso_pending',
      username: name.isNotEmpty ? name : email.split('@').first,
      email: email,
      createdAt: DateTime.now(),
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      elo: json['elo'] as int? ?? 1000,
      clubId: json['clubId'] as String?,
      clubName: json['clubName'] as String?,
      isAdmin: json['isAdmin'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      stats: json['stats'] != null
          ? PlayerStats.fromJson(json['stats'] as Map<String, dynamic>)
          : const PlayerStats(),
    );
  }

  factory UserModel.fromApi(Map<String, dynamic> json) {
    final statsJson = json['stats'] as Map<String, dynamic>?;
    final memberships = json['club_memberships'] as List<dynamic>?;
    final firstMembership = memberships != null && memberships.isNotEmpty
        ? memberships.first as Map<String, dynamic>
        : null;
    final club = firstMembership?['club'] as Map<String, dynamic>?;

    return UserModel(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      elo: (json['elo'] as num?)?.toInt() ?? 1000,
      clubId: club?['id'] as String?,
      clubName: club?['name'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      stats: PlayerStats.fromApi(statsJson ?? const <String, dynamic>{}),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'avatarUrl': avatarUrl,
    'elo': elo,
    'clubId': clubId,
    'clubName': clubName,
    'isAdmin': isAdmin,
    'createdAt': createdAt.toIso8601String(),
    'stats': stats.toJson(),
  };

  bool get isGuest => id == 'guest';
  bool get isSsoPending => id == 'sso_pending';
}

class PlayerStats {
  final int matchesPlayed;
  final int matchesWon;
  final double averageScore;
  final double checkoutRate;
  final int highest180s;
  final int count140Plus;
  final int count100Plus;
  final double bestAverage;

  const PlayerStats({
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.averageScore = 0.0,
    this.checkoutRate = 0.0,
    this.highest180s = 0,
    this.count140Plus = 0,
    this.count100Plus = 0,
    this.bestAverage = 0.0,
  });

  double get winRate =>
      matchesPlayed > 0 ? (matchesWon / matchesPlayed) * 100 : 0;

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    return PlayerStats(
      matchesPlayed: json['matchesPlayed'] as int? ?? 0,
      matchesWon: json['matchesWon'] as int? ?? 0,
      averageScore: (json['averageScore'] as num?)?.toDouble() ?? 0.0,
      checkoutRate: (json['checkoutRate'] as num?)?.toDouble() ?? 0.0,
      highest180s: json['highest180s'] as int? ?? 0,
      count140Plus: json['count140Plus'] as int? ?? 0,
      count100Plus: json['count100Plus'] as int? ?? 0,
      bestAverage: (json['bestAverage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory PlayerStats.fromApi(Map<String, dynamic> json) {
    return PlayerStats(
      matchesPlayed: _toInt(json['matches_played']),
      matchesWon: _toInt(json['matches_won']),
      averageScore: _toDouble(json['avg_score']),
      checkoutRate: _toDouble(json['checkout_rate']),
      highest180s: _toInt(json['total_180s']),
      count140Plus: _toInt(json['count_140_plus']),
      count100Plus: _toInt(json['count_100_plus']),
      bestAverage: _toDouble(json['best_avg']),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? 0;
    }
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() => {
    'matchesPlayed': matchesPlayed,
    'matchesWon': matchesWon,
    'averageScore': averageScore,
    'checkoutRate': checkoutRate,
    'highest180s': highest180s,
    'count140Plus': count140Plus,
    'count100Plus': count100Plus,
    'bestAverage': bestAverage,
  };
}
