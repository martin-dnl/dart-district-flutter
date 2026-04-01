import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/app_constants.dart';
import '../models/match_model.dart';
import 'match_service.dart';

class MatchSpectateRealtimeService {
  MatchSpectateRealtimeService(this._matchService);

  final MatchService _matchService;
  io.Socket? _socket;
  final StreamController<MatchModel> _updates =
      StreamController<MatchModel>.broadcast();

  Stream<MatchModel> get updates => _updates.stream;

  Future<void> connect(String matchId) async {
    final baseUri = Uri.parse(AppConstants.apiBaseUrl);
    final origin =
        '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';

    _socket = io.io(
      '$origin/ws/match',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/socket.io')
          .enableAutoConnect()
          .build(),
    );

    _socket?.onConnect((_) async {
      _socket?.emit('join_match', {'match_id': matchId, 'role': 'spectator'});

      final initial = await _matchService.getMatch(matchId);
      if (!_updates.isClosed) {
        _updates.add(initial);
      }
    });

    _socket?.on('match_update', (data) {
      _emitIfValid(data);
    });

    _socket?.on('match_updated', (data) {
      _emitIfValid(data);
    });

    _socket?.on('score_sync', (_) async {
      final refreshed = await _matchService.getMatch(matchId);
      if (!_updates.isClosed) {
        _updates.add(refreshed);
      }
    });
  }

  void _emitIfValid(dynamic data) {
    if (data is! Map) {
      return;
    }
    final map = data.cast<String, dynamic>();
    final payload = (map['data'] is Map<String, dynamic>)
        ? map['data'] as Map<String, dynamic>
        : map;
    try {
      final parsed = _matchService.matchFromJson(payload);
      if (!_updates.isClosed) {
        _updates.add(parsed);
      }
    } catch (_) {
      // Ignore malformed socket payloads.
    }
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    if (!_updates.isClosed) {
      _updates.close();
    }
  }
}
