class TournamentModel {
  const TournamentModel({
    required this.id,
    required this.name,
    required this.mode,
    required this.finish,
    required this.format,
    required this.maxPlayers,
    required this.enrolledPlayers,
    required this.currentPhase,
    required this.entryFee,
    required this.scheduledAt,
    required this.creatorId,
    required this.creatorUsername,
    required this.status,
    required this.isRegistered,
    this.description,
    this.clubId,
    this.clubName,
    this.clubAddress,
    this.venueName,
    this.venueAddress,
    this.city,
    this.poolCount,
    this.qualifiedPerPool,
    this.playersPerPool,
    this.legsPerSetPool,
    this.setsToWinPool,
    this.legsPerSetBracket,
    this.setsToWinBracket,
  });

  final String id;
  final String name;
  final String? description;
  final String mode;
  final String finish;
  final String format;
  final int maxPlayers;
  final int enrolledPlayers;
  final String currentPhase;
  final String? clubId;
  final String? clubName;
  final String? clubAddress;
  final String? venueName;
  final String? venueAddress;
  final String? city;
  final double entryFee;
  final DateTime scheduledAt;
  final String creatorId;
  final String? creatorUsername;
  final String status;
  final bool isRegistered;
  final int? poolCount;
  final int? playersPerPool;
  final int? qualifiedPerPool;
  final int? legsPerSetPool;
  final int? setsToWinPool;
  final int? legsPerSetBracket;
  final int? setsToWinBracket;

  static int _toInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double _toDouble(dynamic value, {required double fallback}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  factory TournamentModel.fromApi(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final rawPlayers = json['players'];
    final players = rawPlayers is List
        ? rawPlayers.whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];
    final bool isRegistered = players.any(
      (player) => (player['user_id'] ?? '').toString() == currentUserId,
    );

    final creator = json['creator'];
    final club = json['club'] as Map<String, dynamic>?;
    final creatorId = creator is Map<String, dynamic>
        ? (creator['id'] ?? '').toString()
        : (json['created_by'] ?? '').toString();
    final creatorUsername = creator is Map<String, dynamic>
      ? creator['username']?.toString()
      : null;

    return TournamentModel(
      id: (json['id'] ?? json['tournament_id'] ?? '').toString(),
      name: (json['name'] ?? 'Tournoi').toString(),
      description: json['description']?.toString(),
      mode: (json['mode'] ?? '501').toString(),
      finish: (json['finish'] ?? 'double_out').toString(),
      format: (json['format'] ?? 'single_elimination').toString(),
      maxPlayers: _toInt(json['max_players'], fallback: 16),
      enrolledPlayers: _toInt(json['enrolled_players'], fallback: 0),
      currentPhase: (json['current_phase'] ?? 'registration').toString(),
      clubId: club?['id']?.toString(),
      clubName: club?['name']?.toString(),
      clubAddress: club?['address']?.toString(),
      venueName: json['venue_name']?.toString(),
      venueAddress: json['venue_address']?.toString(),
      city: json['city']?.toString(),
      entryFee: _toDouble(json['entry_fee'], fallback: 0),
      scheduledAt:
          DateTime.tryParse((json['scheduled_at'] ?? '').toString()) ??
          DateTime.now(),
      creatorId: creatorId,
      creatorUsername: creatorUsername,
      status: (json['status'] ?? 'open').toString(),
      isRegistered: isRegistered,
      poolCount: _toNullableInt(json['pool_count']),
      playersPerPool: _toNullableInt(json['players_per_pool']),
      qualifiedPerPool: _toNullableInt(json['qualified_per_pool']),
      legsPerSetPool: _toNullableInt(json['legs_per_set_pool']),
      setsToWinPool: _toNullableInt(json['sets_to_win_pool']),
      legsPerSetBracket: _toNullableInt(json['legs_per_set_bracket']),
      setsToWinBracket: _toNullableInt(json['sets_to_win_bracket']),
    );
  }
}
