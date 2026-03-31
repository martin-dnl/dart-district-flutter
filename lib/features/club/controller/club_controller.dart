import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../models/club_model.dart';

class ClubState {
  final ClubModel? club;
  final String tournamentName;
  final String tournamentMeta;
  final String tournamentStatus;
  final bool isLoading;
  final String? error;

  const ClubState({
    this.club,
    this.tournamentName = 'Aucun tournoi',
    this.tournamentMeta = '-',
    this.tournamentStatus = '-',
    this.isLoading = false,
    this.error,
  });

  ClubState copyWith({
    ClubModel? club,
    String? tournamentName,
    String? tournamentMeta,
    String? tournamentStatus,
    bool? isLoading,
    String? error,
  }) {
    return ClubState(
      club: club ?? this.club,
      tournamentName: tournamentName ?? this.tournamentName,
      tournamentMeta: tournamentMeta ?? this.tournamentMeta,
      tournamentStatus: tournamentStatus ?? this.tournamentStatus,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ClubController extends StateNotifier<ClubState> {
  ClubController(this._ref) : super(const ClubState()) {
    _loadClub();
  }

  final Ref _ref;

  Future<void> _loadClub() async {
    state = state.copyWith(isLoading: true);

    try {
      final api = _ref.read(apiClientProvider);
      final meResponse = await api.get<Map<String, dynamic>>('/users/me');
      final meData = meResponse.data?['data'] as Map<String, dynamic>? ??
          const <String, dynamic>{};

      final memberships =
          (meData['club_memberships'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList();

      if (memberships.isEmpty) {
        state = state.copyWith(isLoading: false, club: null);
        return;
      }

      final firstClub = memberships.first['club'] as Map<String, dynamic>?;
      final clubId = firstClub?['id'] as String?;

      if (clubId == null || clubId.isEmpty) {
        state = state.copyWith(isLoading: false, club: null);
        return;
      }

      final clubResponse = await api.get<Map<String, dynamic>>('/clubs/$clubId');
      final clubData = clubResponse.data?['data'] as Map<String, dynamic>? ??
          const <String, dynamic>{};

        final tournamentsResponse =
          await api.get<Map<String, dynamic>>('/tournaments');
        final tournaments =
          (tournamentsResponse.data?['data'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();
        final currentTournament = tournaments.isNotEmpty
          ? tournaments.first
          : const <String, dynamic>{};

        final mode = (currentTournament['mode'] ?? '501').toString();
        final maxClubs = (currentTournament['max_clubs'] ?? 0).toString();
        final status = (currentTournament['status'] ?? 'aucun').toString();

      state = state.copyWith(
        isLoading: false,
        club: ClubModel.fromApi(clubData),
        tournamentName:
          (currentTournament['name'] ?? 'Aucun tournoi').toString(),
        tournamentMeta: '$mode · $maxClubs clubs max',
        tournamentStatus: status,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        club: null,
        error: 'Impossible de charger le club.',
      );
    }
  }
}

final clubControllerProvider =
    StateNotifierProvider<ClubController, ClubState>((ref) {
  return ClubController(ref);
});
