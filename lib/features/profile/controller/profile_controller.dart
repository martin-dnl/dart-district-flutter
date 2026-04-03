import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../../shared/models/match_history_summary.dart';
import '../../auth/controller/auth_controller.dart';
import '../data/profile_service.dart';

class ProfileState {
  final List<MatchHistorySummary> matchHistory;
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
  final String key;
  final String name;
  final String description;
  final String icon;
  final bool unlocked;
  final DateTime? earnedAt;

  const AchievementBadge({
    required this.id,
    required this.key,
    required this.name,
    required this.description,
    this.icon = '🎯',
    this.unlocked = false,
    this.earnedAt,
  });
}

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this._ref) : super(const ProfileState()) {
    _loadProfile();
  }

  final Ref _ref;

  Future<void> refresh() async {
    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    state = const ProfileState(isLoading: true);

    try {
      final api = _ref.read(apiClientProvider);
      final service = ProfileService(api);
      final currentUserId = _ref.read(currentUserProvider)?.id ?? '';

      final statsResponse = await api.get<Map<String, dynamic>>('/stats/me');
      final eloResponse = await api.get<Map<String, dynamic>>(
        '/stats/me/elo-history?limit=20',
      );
      final matchesResponse = await api.get<Map<String, dynamic>>(
        '/matches/me',
        queryParameters: const {'limit': '20', 'status': 'completed'},
      );

      final statsData =
          statsResponse.data?['data'] as Map<String, dynamic>? ??
          const <String, dynamic>{};

      final eloData =
          (eloResponse.data?['data'] as List<dynamic>? ?? <dynamic>[])
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

      final history = matchesData
          .map(
            (raw) =>
                MatchHistorySummary.fromApi(raw, currentUserId: currentUserId),
          )
          .toList();

      List<AchievementBadge> earnedBadges = const <AchievementBadge>[];
      try {
        earnedBadges = await service.getMyBadges();
      } catch (_) {
        earnedBadges = const <AchievementBadge>[];
      }

      state = ProfileState(
        isLoading: false,
        eloHistory: eloHistory,
        matchHistory: history,
        badges: _buildBadges(statsData, earnedBadges),
      );
    } catch (_) {
      state = const ProfileState(isLoading: false);
    }
  }

  List<AchievementBadge> _buildBadges(
    Map<String, dynamic> stats,
    List<AchievementBadge> earnedBadges,
  ) {
    final matchesPlayed = (stats['matches_played'] as num?)?.toInt() ?? 0;
    final total180s = (stats['total_180s'] as num?)?.toInt() ?? 0;
    final checkoutRate = (stats['checkout_rate'] as num?)?.toDouble() ?? 0;
    final earnedByKey = <String, AchievementBadge>{
      for (final b in earnedBadges) b.key: b,
    };

    final defaults = [
      AchievementBadge(
        id: '1',
        key: 'first_win',
        name: 'Premier Match',
        description: 'Jouer son premier match',
        icon: '🎯',
        unlocked: matchesPlayed > 0,
      ),
      AchievementBadge(
        id: '2',
        key: 'first_180',
        name: '180!',
        description: 'Réaliser un 180',
        icon: '🔥',
        unlocked: total180s > 0,
      ),
      AchievementBadge(
        id: '3',
        key: 'checkout_master',
        name: 'Checkout Master',
        description: 'Atteindre 60% de checkout',
        icon: '💎',
        unlocked: checkoutRate >= 60,
      ),
    ];

    return defaults.map((badge) {
      final earned = earnedByKey[badge.key];
      if (earned == null) return badge;
      return AchievementBadge(
        id: earned.id,
        key: badge.key,
        name: earned.name.isEmpty ? badge.name : earned.name,
        description: earned.description.isEmpty
            ? badge.description
            : earned.description,
        icon: earned.icon,
        unlocked: true,
        earnedAt: earned.earnedAt,
      );
    }).toList();
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
      return ProfileController(ref);
    });
