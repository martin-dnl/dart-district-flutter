class PoolStandingEntry {
  const PoolStandingEntry({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.matchesPlayed,
    required this.matchesWon,
    required this.legsWon,
    required this.legsLost,
    required this.points,
    required this.rank,
  });

  final String userId;
  final String username;
  final String? avatarUrl;
  final int matchesPlayed;
  final int matchesWon;
  final int legsWon;
  final int legsLost;
  final int points;
  final int? rank;

  int get legDifference => legsWon - legsLost;

  factory PoolStandingEntry.fromApi(Map<String, dynamic> json) {
    final user = (json['user'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return PoolStandingEntry(
      userId: (json['user_id'] ?? '').toString(),
      username: (user['username'] ?? 'Joueur').toString(),
      avatarUrl: user['avatar_url']?.toString(),
      matchesPlayed: (json['matches_played'] as num?)?.toInt() ?? 0,
      matchesWon: (json['matches_won'] as num?)?.toInt() ?? 0,
      legsWon: (json['legs_won'] as num?)?.toInt() ?? 0,
      legsLost: (json['legs_lost'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt(),
    );
  }
}

class PoolPlayer {
  const PoolPlayer({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.seed,
    this.isQualified = false,
    this.isDisqualified = false,
  });

  final String userId;
  final String username;
  final String? avatarUrl;
  final int? seed;
  final bool isQualified;
  final bool isDisqualified;

  factory PoolPlayer.fromApi(Map<String, dynamic> json) {
    final user = (json['user'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return PoolPlayer(
      userId: (json['user_id'] ?? '').toString(),
      username: (user['username'] ?? 'Joueur').toString(),
      avatarUrl: user['avatar_url']?.toString(),
      seed: (json['seed'] as num?)?.toInt(),
      isQualified: json['is_qualified'] == true,
      isDisqualified: json['is_disqualified'] == true,
    );
  }
}

class PoolModel {
  const PoolModel({
    required this.id,
    required this.tournamentId,
    required this.poolName,
    required this.players,
    required this.standings,
  });

  final String id;
  final String tournamentId;
  final String poolName;
  final List<PoolPlayer> players;
  final List<PoolStandingEntry> standings;

  factory PoolModel.fromApi(
    Map<String, dynamic> json,
    List<PoolStandingEntry> standings,
  ) {
    final playerRows = (json['players'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PoolPlayer.fromApi)
        .toList();

    return PoolModel(
      id: (json['id'] ?? '').toString(),
      tournamentId: (json['tournament_id'] ?? '').toString(),
      poolName: (json['pool_name'] ?? '?').toString(),
      players: playerRows,
      standings: standings,
    );
  }
}
