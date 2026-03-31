import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/app_constants.dart';
import '../models/match_model.dart';

class MatchRealtimeService {
  io.Socket? _socket;
  final StreamController<MatchModel> _invitationStreamController =
      StreamController<MatchModel>.broadcast();
  final StreamController<MatchModel> _scoreUpdateStreamController =
      StreamController<MatchModel>.broadcast();
  final StreamController<bool> _connectionStreamController =
      StreamController<bool>.broadcast();

  Stream<MatchModel> get invitationStream => _invitationStreamController.stream;
  Stream<MatchModel> get scoreUpdateStream =>
      _scoreUpdateStreamController.stream;
  Stream<bool> get connectionStream => _connectionStreamController.stream;

  bool _isConnected = false;
  String? _connectedUserId;
  bool _disposed = false;

  bool get isConnected => _isConnected;

  void connect({required String userId}) {
    if (_disposed) {
      return;
    }

    _connectedUserId = userId;
    final baseUri = Uri.parse(AppConstants.apiBaseUrl);
    final origin =
        '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';

    _socket = io.io(
      '$origin/ws/system',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/socket.io')
          .enableAutoConnect()
          .build(),
    );

    _socket?.onConnect((_) {
      _isConnected = true;
      _connectionStreamController.add(true);
      _socket?.emit('subscribe_user', {'user_id': userId});
    });

    _socket?.onDisconnect((_) {
      _isConnected = false;
      _connectionStreamController.add(false);
    });

    _socket?.on('match_invitation', (data) {
      final match = _matchFromSocket(data);
      _invitationStreamController.add(match);
    });

    _socket?.on('match_score_update', (data) {
      final match = _matchFromSocket(data);
      _scoreUpdateStreamController.add(match);
    });

    _socket?.on('match_invitation_accepted', (data) {
      final match = _matchFromSocket(data);
      _scoreUpdateStreamController.add(match);
    });

    _socket?.on('match_invitation_refused', (data) {
      final match = _matchFromSocket(data);
      _scoreUpdateStreamController.add(match);
    });
  }

  void sendScore({
    required String matchId,
    required int playerIndex,
    required int score,
  }) {
    _socket?.emit('score_sync', {
      'match_id': matchId,
      'player_index': playerIndex,
      'score': score,
      'user_id': _connectedUserId,
    });
  }

  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;

    _socket?.dispose();
    _socket = null;

    if (!_invitationStreamController.isClosed) {
      _invitationStreamController.close();
    }
    if (!_scoreUpdateStreamController.isClosed) {
      _scoreUpdateStreamController.close();
    }
    if (!_connectionStreamController.isClosed) {
      _connectionStreamController.close();
    }
  }

  MatchModel _matchFromSocket(dynamic raw) {
    final data = (raw is Map ? raw : const <String, dynamic>{})
        .cast<String, dynamic>();

    return MatchModel(
      id: (data['id'] ?? '').toString(),
      mode: (data['mode'] ?? '501').toString(),
      startingScore: (data['starting_score'] as num?)?.toInt() ?? 501,
      players:
          (data['players'] as List?)?.map((p) {
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
          (data['starting_player_index'] as num?)?.toInt() ?? 0,
      currentPlayerIndex: (data['current_player_index'] as num?)?.toInt() ?? 0,
      currentRound: (data['current_round'] as num?)?.toInt() ?? 1,
      currentLeg: (data['current_leg'] as num?)?.toInt() ?? 1,
      currentSet: (data['current_set'] as num?)?.toInt() ?? 1,
      status: _parseMatchStatus((data['status'] ?? 'inProgress').toString()),
      roundHistory:
          (data['round_history'] as List?)?.map((r) {
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
      inviterId: (data['inviter_id'] as String?),
      inviteeId: (data['invitee_id'] as String?),
      invitationStatus: _parseInvitationStatus(
        (data['invitation_status'] as String?),
      ),
      setsToWin: (data['sets_to_win'] as num?)?.toInt() ?? 1,
      legsPerSet: (data['legs_per_set'] as num?)?.toInt() ?? 3,
      finishType: (data['finish_type'] ?? 'doubleOut').toString(),
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
