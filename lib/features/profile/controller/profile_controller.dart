import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
class MatchHistory {
  final String id;
  final String opponent;
  final String mode;
  final String score;
  final bool won;
  final DateTime date;
  final double average;
  final int eloChange;

  const MatchHistory({
    required this.id,
    required this.opponent,
    required this.mode,
    required this.score,
    required this.won,
    required this.date,
    this.average = 0,
    this.eloChange = 0,
  });
}

class ProfileState {
  final List<MatchHistory> matchHistory;
  final List<int> eloHistory;
  final List<AchievementBadge> badges;
  final bool isLoading;

  const ProfileState({
    this.matchHistory = const [],
    this.eloHistory = const [],
    this.badges = const [],
    this.isLoading = false,
  });
}

class AchievementBadge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool unlocked;

  const AchievementBadge({
    required this.id,
    required this.name,
    required this.description,
    this.icon = '🎯',
    this.unlocked = false,
  });
}

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this._ref) : super(const ProfileState()) {
    _loadProfile();
  }

  final Ref _ref;

  Future<void> _loadProfile() async {
    state = const ProfileState(isLoading: true);

    try {
      final api = _ref.read(apiClientProvider);

      final statsResponse = await api.get<Map<String, dynamic>>('/stats/me');
      final eloResponse =
          await api.get<Map<String, dynamic>>('/stats/me/elo-history?limit=20');
      final matchesResponse =
          await api.get<Map<String, dynamic>>('/matches/me?limit=20');

      final statsData = statsResponse.data?['data'] as Map<String, dynamic>? ??
          const <String, dynamic>{};

      final eloData = (eloResponse.data?['data'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList();
      final eloHistory = eloData
          .map((entry) => (entry['elo_after'] as num?)?.toInt() ?? 0)
          .where((value) => value > 0)
          .toList()
          .reversed
          .toList();

      final matchesData =
          (matchesResponse.data?['data'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList();
      final history = matchesData.map(_toMatchHistory).toList();

      state = ProfileState(
        isLoading: false,
        eloHistory: eloHistory,
        matchHistory: history,
        badges: _buildBadges(statsData),
      );
    } catch (_) {
      state = const ProfileState(isLoading: false);
    }
  }

  MatchHistory _toMatchHistory(Map<String, dynamic> raw) {
    final createdAt =
        DateTime.tryParse((raw['created_at'] ?? '').toString()) ?? DateTime.now();

    return MatchHistory(
      id: (raw['id'] ?? '').toString(),
      opponent: 'Adversaire',
      mode: (raw['mode'] ?? '501').toString().toUpperCase(),
      score: '${raw['status'] ?? 'in_progress'}',
      won: false,
      date: createdAt,
      average: 0,
      eloChange: 0,
    );
  }

  List<AchievementBadge> _buildBadges(Map<String, dynamic> stats) {
    final matchesPlayed = (stats['matches_played'] as num?)?.toInt() ?? 0;
    final total180s = (stats['total_180s'] as num?)?.toInt() ?? 0;
    final checkoutRate = (stats['checkout_rate'] as num?)?.toDouble() ?? 0;

    return [
      AchievementBadge(
        id: '1',
        name: 'Premier Match',
        description: 'Jouer son premier match',
        icon: '🎯',
        unlocked: matchesPlayed > 0,
      ),
      AchievementBadge(
        id: '2',
        name: '180!',
        description: 'Réaliser un 180',
        icon: '🔥',
        unlocked: total180s > 0,
      ),
      AchievementBadge(
        id: '3',
        name: 'Checkout Master',
        description: 'Atteindre 60% de checkout',
        icon: '💎',
        unlocked: checkoutRate >= 60,
      ),
    ];
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
  return ProfileController(ref);
});
