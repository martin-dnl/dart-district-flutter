import '../../../core/network/api_client.dart';

import '../models/match_model.dart';

class MatchService {
  final ApiClient _api;

  MatchService(this._api);

  /// Create a match invitation
  Future<MatchModel> createMatchInvitation({
    required String inviteeId,
    required String mode,
    required int startingScore,
    required List<String> playerNames,
    required int setsToWin,
    required int legsPerSet,
    required String finishType,
    required bool isRanked,
    bool isTerritorial = false,
  }) async {
    try {
      final response = await _api.post(
        '/matches/invitation',
        data: {
          'invitee_id': inviteeId,
          'mode': mode,
          'starting_score': startingScore,
          'player_names': playerNames,
          'sets_to_win': setsToWin,
          'legs_per_set': legsPerSet,
          'finish_type': finishType,
          'is_ranked': isRanked,
          'is_territorial': isTerritorial,
        },
      );

      return matchFromJson(response.data['data']);
    } catch (e) {
      rethrow;
    }
  }

  /// Get ongoing matches for current user
  Future<List<MatchModel>> getOngoingMatches() async {
    try {
      final response = await _api.get('/matches/ongoing');
      final data = response.data['data'] as List;
      return data.map((m) => matchFromJson(m)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get match by ID
  Future<MatchModel> getMatch(String matchId) async {
    try {
      final response = await _api.get('/matches/$matchId');
      return matchFromJson(response.data['data']);
    } catch (e) {
      rethrow;
    }
  }

  /// Accept a match invitation
  Future<MatchModel> acceptInvitation(String matchId) async {
    try {
      final response = await _api.post('/matches/$matchId/accept');
      return matchFromJson(response.data['data']);
    } catch (e) {
      rethrow;
    }
  }

  /// Refuse a match invitation
  Future<void> refuseInvitation(String matchId) async {
    try {
      await _api.post('/matches/$matchId/refuse');
    } catch (e) {
      rethrow;
    }
  }

  /// Save match score update
  Future<MatchModel> updateMatchScore({
    required String matchId,
    required int playerIndex,
    required int score,
    int? doublesAttempted,
  }) async {
    try {
      final response = await _api.post(
        '/matches/$matchId/score',
        data: {
          'player_index': playerIndex,
          'score': score,
          ...?doublesAttempted == null
              ? null
              : {'doubles_attempted': doublesAttempted},
        },
      );
      return matchFromJson(response.data['data']);
    } catch (e) {
      rethrow;
    }
  }

  /// Cancel/abandon a match
  Future<void> cancelMatch(String matchId) async {
    try {
      await _api.post('/matches/$matchId/cancel');
    } catch (e) {
      rethrow;
    }
  }

  /// Undo last throw on active leg
  Future<MatchModel> undoLastThrow(String matchId) async {
    try {
      final response = await _api.post('/matches/$matchId/undo');
      return matchFromJson(response.data['data']);
    } catch (e) {
      rethrow;
    }
  }

  Future<MatchModel> abandonMatch({
    required String matchId,
    required int surrenderedByIndex,
  }) async {
    try {
      final response = await _api.post(
        '/matches/$matchId/abandon',
        data: {'surrendered_by_index': surrenderedByIndex},
      );
      return matchFromJson(response.data['data']);
    } catch (e) {
      rethrow;
    }
  }

  MatchModel matchFromJson(Map<String, dynamic> json) {
    return MatchModel(
      id: (json['id'] ?? '').toString(),
      mode: (json['mode'] ?? '501').toString(),
      startingScore: (json['starting_score'] as num?)?.toInt() ?? 501,
      players:
          (json['players'] as List?)?.map((p) {
            return PlayerMatch(
              name: (p['name'] ?? 'Joueur').toString(),
              score: (p['score'] as num?)?.toInt() ?? 0,
              legsWon: (p['legs_won'] as num?)?.toInt() ?? 0,
              setsWon: (p['sets_won'] as num?)?.toInt() ?? 0,
              throwScores: ((p['throw_scores'] as List?) ?? []).cast<int>(),
              average: (p['average'] as num?)?.toDouble() ?? 0.0,
              doublesAttempted: (p['doubles_attempted'] as num?)?.toInt() ?? 0,
              doublesHit: (p['doubles_hit'] as num?)?.toInt() ?? 0,
            );
          }).toList() ??
          const [],
      startingPlayerIndex:
          (json['starting_player_index'] as num?)?.toInt() ?? 0,
      currentPlayerIndex: (json['current_player_index'] as num?)?.toInt() ?? 0,
      currentRound: (json['current_round'] as num?)?.toInt() ?? 1,
      currentLeg: (json['current_leg'] as num?)?.toInt() ?? 1,
      currentSet: (json['current_set'] as num?)?.toInt() ?? 1,
      status: _parseMatchStatus((json['status'] ?? 'inProgress').toString()),
      roundHistory:
          (json['round_history'] as List?)?.map((r) {
            return RoundScore(
              playerIndex: (r['player_index'] as num?)?.toInt() ?? 0,
              round: (r['round'] as num?)?.toInt() ?? 1,
              darts: ((r['darts'] as List?) ?? []).cast<int>(),
              total: (r['total'] as num?)?.toInt() ?? 0,
              isBust: (r['is_bust'] as bool?) ?? false,
              doublesAttempted: (r['doubles_attempted'] as num?)?.toInt() ?? 0,
            );
          }).toList() ??
          const [],
      inviterId: (json['inviter_id'] as String?),
      inviteeId: (json['invitee_id'] as String?),
      invitationStatus: _parseInvitationStatus(
        (json['invitation_status'] as String?),
      ),
      invitationCreatedAt: DateTime.tryParse(
        (json['invitation_created_at'] ?? '').toString(),
      ),
      setsToWin: (json['sets_to_win'] as num?)?.toInt() ?? 1,
      legsPerSet: (json['legs_per_set'] as num?)?.toInt() ?? 3,
      finishType: (json['finish_type'] ?? 'doubleOut').toString(),
      isRanked: (json['is_ranked'] as bool?) ?? true,
      isTerritorial: (json['is_territorial'] as bool?) ?? false,
      abandonedByIndex: (json['abandoned_by_index'] as num?)?.toInt(),
    );
  }

  MatchStatus _parseMatchStatus(String status) {
    switch (status) {
      case 'waiting':
        return MatchStatus.waiting;
      case 'inProgress':
      case 'in_progress':
        return MatchStatus.inProgress;
      case 'finished':
        return MatchStatus.finished;
      default:
        return MatchStatus.inProgress;
    }
  }

  InvitationStatus? _parseInvitationStatus(String? status) {
    if (status == null) return null;
    switch (status) {
      case 'pending':
        return InvitationStatus.pending;
      case 'accepted':
        return InvitationStatus.accepted;
      case 'refused':
        return InvitationStatus.refused;
      default:
        return null;
    }
  }
}
