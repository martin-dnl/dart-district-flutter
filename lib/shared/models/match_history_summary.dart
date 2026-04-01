class MatchHistorySummary {
  const MatchHistorySummary({
    required this.matchId,
    required this.opponentName,
    this.opponentAvatarUrl,
    required this.setsScore,
    required this.won,
    required this.isRanked,
    required this.playedAt,
    required this.mode,
  });

  final String matchId;
  final String opponentName;
  final String? opponentAvatarUrl;
  final String setsScore;
  final bool won;
  final bool isRanked;
  final DateTime playedAt;
  final String mode;

  factory MatchHistorySummary.fromApi(
    Map<String, dynamic> raw, {
    required String currentUserId,
  }) {
    final players = (raw['players'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();

    final me = _resolveCurrentPlayer(players, currentUserId);
    final opponent = _resolveOpponentPlayer(players, currentUserId);

    final mySets = _toInt(me?['sets_won'] ?? raw['my_sets_won']);
    final opponentSets = _toInt(
      opponent?['sets_won'] ?? raw['opponent_sets_won'],
    );

    final won = (raw['winner_id']?.toString().isNotEmpty == true)
        ? raw['winner_id'].toString() == currentUserId
        : (me?['is_winner'] == true || mySets > opponentSets);

    final playedAt =
        DateTime.tryParse(
          (raw['completed_at'] ?? raw['created_at'] ?? '').toString(),
        ) ??
        DateTime.now();

    return MatchHistorySummary(
      matchId: (raw['id'] ?? '').toString(),
      opponentName:
          (opponent?['username'] ??
                  opponent?['name'] ??
                  raw['opponent_username'] ??
                  'Adversaire')
              .toString(),
      opponentAvatarUrl: (opponent?['avatar_url'] ?? opponent?['avatarUrl'])
          ?.toString(),
      setsScore: '$mySets - $opponentSets',
      won: won,
      isRanked: raw['is_ranked'] == true,
      playedAt: playedAt,
      mode: (raw['mode'] ?? '501').toString().toUpperCase(),
    );
  }

  static Map<String, dynamic>? _resolveCurrentPlayer(
    List<Map<String, dynamic>> players,
    String currentUserId,
  ) {
    for (final player in players) {
      final userId = player['user_id'] ?? player['id'];
      if (userId?.toString() == currentUserId) {
        return player;
      }
    }
    return players.isNotEmpty ? players.first : null;
  }

  static Map<String, dynamic>? _resolveOpponentPlayer(
    List<Map<String, dynamic>> players,
    String currentUserId,
  ) {
    for (final player in players) {
      final userId = player['user_id'] ?? player['id'];
      if (userId?.toString() != currentUserId) {
        return player;
      }
    }
    return players.length > 1 ? players[1] : null;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? (double.tryParse(value)?.toInt() ?? 0);
    }
    return 0;
  }
}
