class RecentMatchSummary {
  const RecentMatchSummary({
    required this.id,
    required this.opponentName,
    required this.setsScore,
    required this.won,
  });

  final String id;
  final String opponentName;
  final String setsScore;
  final bool won;

  factory RecentMatchSummary.fromApi(
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

    return RecentMatchSummary(
      id: (raw['id'] ?? '').toString(),
      opponentName:
          (opponent?['username'] ??
                  opponent?['name'] ??
                  raw['opponent_username'] ??
                  'Adversaire')
              .toString(),
      setsScore: '$mySets - $opponentSets',
      won: won,
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
