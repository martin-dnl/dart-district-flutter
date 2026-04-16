import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../../features/auth/controller/auth_controller.dart';
import '../models/bracket_match_model.dart';
import '../models/pool_model.dart';
import '../models/tournament_model.dart';

class TournamentPlayerModel {
  const TournamentPlayerModel({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.elo,
    this.seed,
    this.isQualified = false,
    this.isDisqualified = false,
  });

  final String userId;
  final String username;
  final String? avatarUrl;
  final int? elo;
  final int? seed;
  final bool isQualified;
  final bool isDisqualified;

  factory TournamentPlayerModel.fromApi(Map<String, dynamic> json) {
    final user = (json['user'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return TournamentPlayerModel(
      userId: (json['user_id'] ?? '').toString(),
      username: (user['username'] ?? 'Joueur').toString(),
      avatarUrl: user['avatar_url']?.toString(),
      elo: (user['elo'] as num?)?.toInt(),
      seed: (json['seed'] as num?)?.toInt(),
      isQualified: json['is_qualified'] == true,
      isDisqualified: json['is_disqualified'] == true,
    );
  }
}

class TournamentDetailModel {
  const TournamentDetailModel({
    required this.tournament,
    required this.players,
  });

  final TournamentModel tournament;
  final List<TournamentPlayerModel> players;
}

class PlayerLeaderboardEntry {
  const PlayerLeaderboardEntry({
    required this.id,
    required this.username,
    required this.elo,
    required this.conquestScore,
  });

  final String id;
  final String username;
  final int elo;
  final int conquestScore;

  factory PlayerLeaderboardEntry.fromApi(Map<String, dynamic> json) {
    return PlayerLeaderboardEntry(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? 'Joueur').toString(),
      elo: (json['elo'] as num?)?.toInt() ?? 1000,
      conquestScore: (json['conquest_score'] as num?)?.toInt() ?? 0,
    );
  }
}

class TournamentService {
  TournamentService(this.ref);

  final Ref ref;

  dynamic _extractData(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      if (payload['data'] != null) {
        final data = payload['data'];
        if (data is Map<String, dynamic> && data['items'] != null) {
          return data['items'];
        }
        return data;
      }

      if (payload['items'] != null) {
        return payload['items'];
      }

      if (payload['tournaments'] != null) {
        return payload['tournaments'];
      }
    }
    return payload;
  }

  List<Map<String, dynamic>> _extractRows(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    if (raw is Map<String, dynamic>) {
      final items = raw['items'];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList();
      }

      final tournaments = raw['tournaments'];
      if (tournaments is List) {
        return tournaments.whereType<Map<String, dynamic>>().toList();
      }

      final rows = raw['rows'];
      if (rows is List) {
        return rows.whereType<Map<String, dynamic>>().toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  Future<List<TournamentModel>> listTournaments({String? status}) async {
    final api = ref.read(apiClientProvider);
    final auth = ref.read(authControllerProvider);
    final userId = auth.user?.id ?? '';

    final queryParameters = <String, dynamic>{};
    if (status != null && status.trim().isNotEmpty) {
      queryParameters['status'] = status.trim();
    }

    final response = await api.get<dynamic>(
      '/tournaments',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final raw = _extractData(response.data);
    final rows = _extractRows(raw);
    final models = <TournamentModel>[];
    for (final row in rows) {
      try {
        models.add(TournamentModel.fromApi(row, currentUserId: userId));
      } catch (_) {
        // Skip malformed rows instead of failing the full screen.
      }
    }
    return models;
  }

  Future<TournamentDetailModel> fetchDetail(String tournamentId) async {
    final api = ref.read(apiClientProvider);
    final auth = ref.read(authControllerProvider);
    final userId = auth.user?.id ?? '';

    final response = await api.get<dynamic>('/tournaments/$tournamentId');
    final raw = _extractData(response.data);
    final map = (raw as Map<String, dynamic>? ?? <String, dynamic>{});

    final players = (map['players'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(TournamentPlayerModel.fromApi)
        .toList();

    return TournamentDetailModel(
      tournament: TournamentModel.fromApi(map, currentUserId: userId),
      players: players,
    );
  }

  Future<void> register(String tournamentId) async {
    final api = ref.read(apiClientProvider);
    await api.post<Map<String, dynamic>>('/tournaments/$tournamentId/register');
  }

  Future<void> unregister(String tournamentId) async {
    final api = ref.read(apiClientProvider);
    await api.delete<Map<String, dynamic>>(
      '/tournaments/$tournamentId/register',
    );
  }

  Future<List<PoolModel>> fetchPools(String tournamentId) async {
    final api = ref.read(apiClientProvider);
    final response = await api.get<Map<String, dynamic>>(
      '/tournaments/$tournamentId/pools',
    );
    final raw = _extractData(response.data);
    final pools = (raw is List ? raw : <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();

    final List<PoolModel> models = [];
    for (final pool in pools) {
      final poolId = (pool['id'] ?? '').toString();
      final standingsResponse = await api.get<Map<String, dynamic>>(
        '/tournaments/$tournamentId/pools/$poolId/standings',
      );
      final standingsRaw = _extractData(standingsResponse.data);
      final standings = (standingsRaw is List ? standingsRaw : <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(PoolStandingEntry.fromApi)
          .toList();
      models.add(PoolModel.fromApi(pool, standings));
    }
    return models;
  }

  Future<List<BracketMatchModel>> fetchBracket(String tournamentId) async {
    final api = ref.read(apiClientProvider);
    final response = await api.get<Map<String, dynamic>>(
      '/tournaments/$tournamentId/bracket',
    );
    final raw = _extractData(response.data);
    final rows = (raw is List ? raw : <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(BracketMatchModel.fromApi)
        .toList();
    return rows;
  }

  Future<void> generatePools(String tournamentId) async {
    final api = ref.read(apiClientProvider);
    await api.post<Map<String, dynamic>>('/tournaments/$tournamentId/pools');
  }

  Future<void> generateBracket(String tournamentId) async {
    final api = ref.read(apiClientProvider);
    await api.post<Map<String, dynamic>>('/tournaments/$tournamentId/bracket');
  }

  Future<void> advance(String tournamentId) async {
    final api = ref.read(apiClientProvider);
    await api.post<Map<String, dynamic>>('/tournaments/$tournamentId/advance');
  }

  Future<void> disqualify({
    required String tournamentId,
    required String playerId,
    required String reason,
  }) async {
    final api = ref.read(apiClientProvider);
    await api.post<Map<String, dynamic>>(
      '/tournaments/$tournamentId/disqualify/$playerId',
      data: {'reason': reason},
    );
  }

  Future<void> createTournament(Map<String, dynamic> payload) async {
    final api = ref.read(apiClientProvider);
    await api.post<Map<String, dynamic>>('/tournaments', data: payload);
  }

  Future<List<PlayerLeaderboardEntry>> fetchPlayerLeaderboard({
    required String metric,
    int limit = 50,
    String? query,
  }) async {
    final api = ref.read(apiClientProvider);
    final queryParameters = <String, dynamic>{
      'metric': metric,
      'limit': '$limit',
      if ((query ?? '').trim().isNotEmpty) 'q': query!.trim(),
    };

    final response = await api.get<Map<String, dynamic>>(
      '/users/leaderboard',
      queryParameters: queryParameters,
    );

    final rows = (response.data?['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    return rows
        .map(PlayerLeaderboardEntry.fromApi)
        .where((entry) => entry.id.isNotEmpty)
        .toList(growable: false);
  }
}

final tournamentServiceProvider = Provider<TournamentService>((ref) {
  return TournamentService(ref);
});
