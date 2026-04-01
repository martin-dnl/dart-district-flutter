class BracketMatchModel {
  const BracketMatchModel({
    required this.id,
    required this.tournamentId,
    required this.roundNumber,
    required this.position,
    required this.status,
    this.player1Id,
    this.player2Id,
    this.winnerId,
    this.matchId,
    this.player1Name,
    this.player2Name,
  });

  final String id;
  final String tournamentId;
  final int roundNumber;
  final int position;
  final String status;
  final String? player1Id;
  final String? player2Id;
  final String? winnerId;
  final String? matchId;
  final String? player1Name;
  final String? player2Name;

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';

  factory BracketMatchModel.fromApi(Map<String, dynamic> json) {
    final player1 =
        (json['player1'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final player2 =
        (json['player2'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return BracketMatchModel(
      id: (json['id'] ?? '').toString(),
      tournamentId: (json['tournament_id'] ?? '').toString(),
      roundNumber: (json['round_number'] as num?)?.toInt() ?? 1,
      position: (json['position'] as num?)?.toInt() ?? 1,
      status: (json['status'] ?? 'pending').toString(),
      player1Id: json['player1_id']?.toString(),
      player2Id: json['player2_id']?.toString(),
      winnerId: json['winner_id']?.toString(),
      matchId: json['match_id']?.toString(),
      player1Name: player1['username']?.toString(),
      player2Name: player2['username']?.toString(),
    );
  }
}
