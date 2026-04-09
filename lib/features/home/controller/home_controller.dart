import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';

class HomeState {
  final bool isLoading;
  final String clubName;
  final String location;
  final int territoriesControlled;
  final int conquestPoints;
  final int clubRank;
  final String pendingMatch;
  final List<bool> recentResults;
  final String recentRecord;
  final String recentOpponent;
  final String recentScore;
  final String tournamentType;
  final String tournamentTitle;
  final String tournamentCountdown;
  final String tournamentSlots;

  const HomeState({
    this.isLoading = true,
    this.clubName = 'Mon Club',
    this.location = 'Inconnue',
    this.territoriesControlled = 0,
    this.conquestPoints = 0,
    this.clubRank = 0,
    this.pendingMatch = 'Aucun match en attente',
    this.recentResults = const <bool>[],
    this.recentRecord = '0% Victoires',
    this.recentOpponent = '-',
    this.recentScore = '-',
    this.tournamentType = 'Local',
    this.tournamentTitle = 'Aucun tournoi',
    this.tournamentCountdown = '-',
    this.tournamentSlots = '0/0',
  });

  HomeState copyWith({
    bool? isLoading,
    String? clubName,
    String? location,
    int? territoriesControlled,
    int? conquestPoints,
    int? clubRank,
    String? pendingMatch,
    List<bool>? recentResults,
    String? recentRecord,
    String? recentOpponent,
    String? recentScore,
    String? tournamentType,
    String? tournamentTitle,
    String? tournamentCountdown,
    String? tournamentSlots,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      clubName: clubName ?? this.clubName,
      location: location ?? this.location,
      territoriesControlled:
          territoriesControlled ?? this.territoriesControlled,
      conquestPoints: conquestPoints ?? this.conquestPoints,
      clubRank: clubRank ?? this.clubRank,
      pendingMatch: pendingMatch ?? this.pendingMatch,
      recentResults: recentResults ?? this.recentResults,
      recentRecord: recentRecord ?? this.recentRecord,
      recentOpponent: recentOpponent ?? this.recentOpponent,
      recentScore: recentScore ?? this.recentScore,
      tournamentType: tournamentType ?? this.tournamentType,
      tournamentTitle: tournamentTitle ?? this.tournamentTitle,
      tournamentCountdown: tournamentCountdown ?? this.tournamentCountdown,
      tournamentSlots: tournamentSlots ?? this.tournamentSlots,
    );
  }
}

class HomeController extends StateNotifier<HomeState> {
  HomeController(this._ref) : super(const HomeState()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(isLoading: true);

    try {
      final api = _ref.read(apiClientProvider);

      final meResponse = await api.get<Map<String, dynamic>>('/users/me');
      final meData =
          meResponse.data?['data'] as Map<String, dynamic>? ??
          const <String, dynamic>{};

      final memberships =
          (meData['club_memberships'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList();
      final club = memberships.isNotEmpty
          ? memberships.first['club'] as Map<String, dynamic>?
          : null;

      final clubId = club?['id'] as String?;
      Map<String, dynamic> clubData = const <String, dynamic>{};
      var conquestPointsTotal = 0;
      if (clubId != null && clubId.isNotEmpty) {
        final clubResponse = await api.get<Map<String, dynamic>>(
          '/clubs/$clubId',
        );
        clubData =
            clubResponse.data?['data'] as Map<String, dynamic>? ??
            const <String, dynamic>{};

        try {
          final pointsResponse = await api.get<Map<String, dynamic>>(
            '/clubs/$clubId/territory-points-total',
          );
          final payload =
              pointsResponse.data?['data'] as Map<String, dynamic>? ??
              pointsResponse.data ??
              const <String, dynamic>{};
          conquestPointsTotal = (payload['points'] as num?)?.toInt() ?? 0;
        } catch (_) {
          conquestPointsTotal =
              (clubData['conquest_points'] as num?)?.toInt() ?? 0;
        }
      }

      final territoriesResponse = await api.get<Map<String, dynamic>>(
        '/territories',
      );
      final territories =
          (territoriesResponse.data?['data'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList();
      final owned = territories.where((t) {
        final owner = t['owner_club'] as Map<String, dynamic>?;
        return owner?['id'] == clubId;
      }).length;

      final matchesResponse = await api.get<Map<String, dynamic>>(
        '/matches/me?limit=5',
      );
      final matches =
          (matchesResponse.data?['data'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList();

      final pending = matches
          .where((m) => (m['status'] ?? '').toString() == 'awaiting_validation')
          .toList();
      final recentResults = matches
          .map((m) => (m['status'] ?? '').toString() == 'completed')
          .take(5)
          .toList();
      final winRatio = recentResults.isEmpty
          ? 0
          : ((recentResults.where((w) => w).length / recentResults.length) *
                    100)
                .round();

      final tournamentsResponse = await api.get<Map<String, dynamic>>(
        '/tournaments',
      );
      final tournaments =
          (tournamentsResponse.data?['data'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList();
      final tournament = tournaments.isNotEmpty
          ? tournaments.first
          : const <String, dynamic>{};

      state = state.copyWith(
        isLoading: false,
        clubName: (clubData['name'] ?? club?['name'] ?? 'Mon Club').toString(),
        location: (clubData['city'] ?? meData['city'] ?? 'Inconnue').toString(),
        territoriesControlled: owned,
        conquestPoints: conquestPointsTotal,
        clubRank: (clubData['rank'] as num?)?.toInt() ?? 0,
        pendingMatch: pending.isNotEmpty
            ? 'Match en attente de validation'
            : 'Aucun match en attente',
        recentResults: recentResults,
        recentRecord: '$winRatio% Victoires',
        recentOpponent: matches.isNotEmpty ? 'Dernier match' : '-',
        recentScore: matches.isNotEmpty
            ? (matches.first['status'] ?? '-').toString()
            : '-',
        tournamentType: (tournament['is_territorial'] == true)
            ? 'Territorial'
            : 'Local',
        tournamentTitle: (tournament['name'] ?? 'Aucun tournoi').toString(),
        tournamentCountdown: _humanizeDate(tournament['scheduled_at']),
        tournamentSlots:
            '${(tournament['enrolled_players'] ?? 0).toString()}/${(tournament['max_players'] ?? 0).toString()}',
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  String _humanizeDate(dynamic rawDate) {
    final date = DateTime.tryParse((rawDate ?? '').toString());
    if (date == null) return '-';
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    if (diff <= 0) return 'Aujourd\'hui';
    if (diff == 1) return 'Dans 1 jour';
    return 'Dans $diff jours';
  }
}

final homeControllerProvider = StateNotifierProvider<HomeController, HomeState>(
  (ref) {
    return HomeController(ref);
  },
);
