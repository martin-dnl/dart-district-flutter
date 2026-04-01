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
    required this.status,
    required this.isRegistered,
    this.description,
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
  final String? venueName;
  final String? venueAddress;
  final String? city;
  final double entryFee;
  final DateTime scheduledAt;
  final String creatorId;
  final String status;
  final bool isRegistered;
  final int? poolCount;
  final int? playersPerPool;
  final int? qualifiedPerPool;
  final int? legsPerSetPool;
  final int? setsToWinPool;
  final int? legsPerSetBracket;
  final int? setsToWinBracket;

  factory TournamentModel.fromApi(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final players = (json['players'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
    final bool isRegistered = players.any(
      (player) => (player['user_id'] ?? '').toString() == currentUserId,
    );

    return TournamentModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Tournoi').toString(),
      description: json['description']?.toString(),
      mode: (json['mode'] ?? '501').toString(),
      finish: (json['finish'] ?? 'double_out').toString(),
      format: (json['format'] ?? 'single_elimination').toString(),
      maxPlayers: (json['max_players'] as num?)?.toInt() ?? 16,
      enrolledPlayers: (json['enrolled_players'] as num?)?.toInt() ?? 0,
      currentPhase: (json['current_phase'] ?? 'registration').toString(),
      venueName: json['venue_name']?.toString(),
      venueAddress: json['venue_address']?.toString(),
      city: json['city']?.toString(),
      entryFee: (json['entry_fee'] as num?)?.toDouble() ?? 0,
      scheduledAt:
          DateTime.tryParse((json['scheduled_at'] ?? '').toString()) ??
          DateTime.now(),
      creatorId:
          (json['created_by'] ??
                  (json['creator'] as Map<String, dynamic>?)?['id'] ??
                  '')
              .toString(),
      status: (json['status'] ?? 'open').toString(),
      isRegistered: isRegistered,
      poolCount: (json['pool_count'] as num?)?.toInt(),
      playersPerPool: (json['players_per_pool'] as num?)?.toInt(),
      qualifiedPerPool: (json['qualified_per_pool'] as num?)?.toInt(),
      legsPerSetPool: (json['legs_per_set_pool'] as num?)?.toInt(),
      setsToWinPool: (json['sets_to_win_pool'] as num?)?.toInt(),
      legsPerSetBracket: (json['legs_per_set_bracket'] as num?)?.toInt(),
      setsToWinBracket: (json['sets_to_win_bracket'] as num?)?.toInt(),
    );
  }
}
