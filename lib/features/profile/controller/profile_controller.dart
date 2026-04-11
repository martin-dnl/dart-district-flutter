import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../../shared/models/match_history_summary.dart';
import '../../auth/controller/auth_controller.dart';
import '../data/profile_service.dart';

enum EloPeriodMode { week, month, year }

class EloPeriodPoint {
  const EloPeriodPoint({required this.label, required this.elo});

  final String label;
  final int elo;
}

class ProfileState {
  final List<MatchHistorySummary> matchHistory;
  final List<int> eloHistory;
  final List<EloPeriodPoint> eloPoints;
  final EloPeriodMode eloMode;
  final int eloOffset;
  final String eloPeriodLabel;
  final bool isEloLoading;
  final List<AchievementBadge> badges;
  final bool isLoading;

  const ProfileState({
    this.matchHistory = const [],
    this.eloHistory = const [],
    this.eloPoints = const [],
    this.eloMode = EloPeriodMode.week,
    this.eloOffset = 0,
    this.eloPeriodLabel = '',
    this.isEloLoading = false,
    this.badges = const [],
    this.isLoading = false,
  });

  ProfileState copyWith({
    List<MatchHistorySummary>? matchHistory,
    List<int>? eloHistory,
    List<EloPeriodPoint>? eloPoints,
    EloPeriodMode? eloMode,
    int? eloOffset,
    String? eloPeriodLabel,
    bool? isEloLoading,
    List<AchievementBadge>? badges,
    bool? isLoading,
  }) {
    return ProfileState(
      matchHistory: matchHistory ?? this.matchHistory,
      eloHistory: eloHistory ?? this.eloHistory,
      eloPoints: eloPoints ?? this.eloPoints,
      eloMode: eloMode ?? this.eloMode,
      eloOffset: eloOffset ?? this.eloOffset,
      eloPeriodLabel: eloPeriodLabel ?? this.eloPeriodLabel,
      isEloLoading: isEloLoading ?? this.isEloLoading,
      badges: badges ?? this.badges,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AchievementBadge {
  final String id;
  final String key;
  final String name;
  final String description;
  final String icon;
  final String difficulty;
  final bool unlocked;
  final DateTime? earnedAt;

  const AchievementBadge({
    required this.id,
    required this.key,
    required this.name,
    required this.description,
    this.icon = '🎯',
    this.difficulty = 'Bronze',
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

  Future<void> setEloMode(EloPeriodMode mode) async {
    state = state.copyWith(eloMode: mode, eloOffset: 0);
    await _loadEloPeriod();
  }

  Future<void> shiftEloPeriod(int delta) async {
    final nextOffset = (state.eloOffset + delta).clamp(0, 120);
    if (nextOffset == state.eloOffset) {
      return;
    }
    state = state.copyWith(eloOffset: nextOffset);
    await _loadEloPeriod();
  }

  Future<void> _loadProfile() async {
    state = state.copyWith(isLoading: true);

    try {
      final api = _ref.read(apiClientProvider);
      final service = ProfileService(api);
      final currentUserId = _ref.read(currentUserProvider)?.id ?? '';

      final statsResponse = await api.get<Map<String, dynamic>>('/stats/me');
      final eloResponse = await api.get<Map<String, dynamic>>(
        '/stats/me/elo-history',
        queryParameters: {
          'mode': state.eloMode.name,
          'offset': state.eloOffset,
        },
      );
      final matchesResponse = await api.get<Map<String, dynamic>>(
        '/matches/me',
        queryParameters: const {
          'limit': '5',
          'status': 'completed',
          'ranked': 'true',
        },
      );

      final statsData =
          statsResponse.data?['data'] as Map<String, dynamic>? ??
          const <String, dynamic>{};

      final eloPayload =
          (eloResponse.data?['data'] as Map<String, dynamic>?) ??
          eloResponse.data ??
          const <String, dynamic>{};
      final eloPoints = (eloPayload['points'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(
            (entry) => EloPeriodPoint(
              label: (entry['date'] ?? '').toString(),
              elo: (entry['elo'] as num?)?.toInt() ?? 0,
            ),
          )
          .where((point) => point.elo > 0)
          .toList(growable: false);

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

      state = state.copyWith(
        isLoading: false,
        isEloLoading: false,
        eloPoints: eloPoints,
        eloHistory: eloPoints.map((point) => point.elo).toList(growable: false),
        eloPeriodLabel: (eloPayload['period_label'] ?? '').toString(),
        matchHistory: history,
        badges: _buildBadges(statsData, earnedBadges),
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, isEloLoading: false);
    }
  }

  Future<void> _loadEloPeriod() async {
    state = state.copyWith(isEloLoading: true);
    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.get<Map<String, dynamic>>(
        '/stats/me/elo-history',
        queryParameters: {
          'mode': state.eloMode.name,
          'offset': state.eloOffset,
        },
      );
      final payload =
          (response.data?['data'] as Map<String, dynamic>?) ??
          response.data ??
          const <String, dynamic>{};
      final points = (payload['points'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(
            (entry) => EloPeriodPoint(
              label: (entry['date'] ?? '').toString(),
              elo: (entry['elo'] as num?)?.toInt() ?? 0,
            ),
          )
          .where((point) => point.elo > 0)
          .toList(growable: false);

      state = state.copyWith(
        isEloLoading: false,
        eloPoints: points,
        eloHistory: points.map((point) => point.elo).toList(growable: false),
        eloPeriodLabel: (payload['period_label'] ?? '').toString(),
      );
    } catch (_) {
      state = state.copyWith(isEloLoading: false);
    }
  }

  List<AchievementBadge> _buildBadges(
    Map<String, dynamic> stats,
    List<AchievementBadge> earnedBadges,
  ) {
    final matchesPlayed = (stats['matches_played'] as num?)?.toInt() ?? 0;
    final matchesWon = (stats['matches_won'] as num?)?.toInt() ?? 0;
    final total180s = (stats['total_180s'] as num?)?.toInt() ?? 0;
    final count140Plus = (stats['count_140_plus'] as num?)?.toInt() ?? 0;
    final bestAvg = (stats['best_avg'] as num?)?.toDouble() ?? 0;
    final highFinish = (stats['high_finish'] as num?)?.toInt() ?? 0;
    final streakDays = (stats['consecutive_days_played'] as num?)?.toInt() ?? 0;
    final checkoutRate = (stats['checkout_rate'] as num?)?.toDouble() ?? 0;
    final earnedByKey = <String, AchievementBadge>{
      for (final b in earnedBadges) b.key: b,
    };

    final defaults = <AchievementBadge>[
      AchievementBadge(
        id: '1',
        key: 'rookie_first_match',
        name: 'Premier Match',
        description: 'Jouer son premier match',
        icon: '🎯',
        difficulty: 'Bronze',
        unlocked: matchesPlayed > 0,
      ),
      AchievementBadge(
        id: '2',
        key: 'grinder_10',
        name: 'Serie 10',
        description: 'Jouer 10 matchs classes',
        icon: '🧱',
        difficulty: 'Bronze',
        unlocked: matchesPlayed >= 10,
      ),
      AchievementBadge(
        id: '3',
        key: 'centurion',
        name: 'Centurion',
        description: 'Jouer 100 matchs classes',
        icon: '🏛️',
        difficulty: 'Or',
        unlocked: matchesPlayed >= 100,
      ),
      AchievementBadge(
        id: '4',
        key: 'first_win',
        name: 'Premiere Victoire',
        description: 'Gagner son premier match',
        icon: '🥇',
        difficulty: 'Bronze',
        unlocked: matchesWon >= 1,
      ),
      AchievementBadge(
        id: '5',
        key: 'win_machine',
        name: 'Machine a Gagner',
        description: 'Atteindre 50 victoires',
        icon: '🏆',
        difficulty: 'Or',
        unlocked: matchesWon >= 50,
      ),
      AchievementBadge(
        id: '6',
        key: 'first_180',
        name: '180!',
        description: 'Réaliser un 180',
        icon: '🔥',
        difficulty: 'Argent',
        unlocked: total180s > 0,
      ),
      AchievementBadge(
        id: '7',
        key: 'triple_thunder',
        name: 'Triple Foudre',
        description: 'Réaliser 3 fois 180',
        icon: '⚡',
        difficulty: 'Or',
        unlocked: total180s >= 3,
      ),
      AchievementBadge(
        id: '8',
        key: 'ton_80_master',
        name: 'Ton-80 Master',
        description: 'Realiser 10 fois 180',
        icon: '💫',
        difficulty: 'Diamant',
        unlocked: total180s >= 10,
      ),
      AchievementBadge(
        id: '9',
        key: 'factory_140',
        name: '140+ Factory',
        description: 'Faire 25 scores a 140+',
        icon: '💥',
        difficulty: 'Argent',
        unlocked: count140Plus >= 25,
      ),
      AchievementBadge(
        id: '10',
        key: 'checkout_sniper',
        name: 'Sniper Checkout',
        description: 'Atteindre 40% de checkout',
        icon: '🎯',
        difficulty: 'Argent',
        unlocked: checkoutRate >= 40,
      ),
      AchievementBadge(
        id: '11',
        key: 'checkout_master',
        name: 'Checkout Master',
        description: 'Atteindre 60% de checkout',
        icon: '💎',
        difficulty: 'Diamant',
        unlocked: checkoutRate >= 60,
      ),
      AchievementBadge(
        id: '12',
        key: 'high_finish_100',
        name: 'Big Fish',
        description: 'Realiser un finish de 100+',
        icon: '🐟',
        difficulty: 'Argent',
        unlocked: highFinish >= 100,
      ),
      AchievementBadge(
        id: '13',
        key: 'high_finish_150',
        name: 'Finisseur Elite',
        description: 'Realiser un finish de 150+',
        icon: '🦈',
        difficulty: 'Or',
        unlocked: highFinish >= 150,
      ),
      AchievementBadge(
        id: '14',
        key: 'avg_75',
        name: 'Meme Lord 75',
        description: 'Signer une meilleure moyenne a 75+',
        icon: '🗿',
        difficulty: 'Legende',
        unlocked: bestAvg >= 75,
      ),
      AchievementBadge(
        id: '15',
        key: 'streak_3_days',
        name: 'Regulier',
        description: 'Jouer 3 jours d\'affilee',
        icon: '📅',
        difficulty: 'Bronze',
        unlocked: streakDays >= 3,
      ),
      AchievementBadge(
        id: '16',
        key: 'territory_warlord',
        name: 'Conquerant IRIS',
        description: 'Faire gagner une zone a son club',
        icon: '🗺️',
        difficulty: 'Legende',
        unlocked: earnedByKey['territory_warlord'] != null,
      ),
      AchievementBadge(
        id: '17',
        key: 'tournament_king',
        name: 'Roi du Tournoi',
        description: 'Remporter un tournoi officiel',
        icon: '👑',
        difficulty: 'Legende',
        unlocked: earnedByKey['tournament_king'] != null,
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
        icon: earned.icon.isEmpty ? badge.icon : earned.icon,
        difficulty: earned.difficulty.isEmpty
            ? badge.difficulty
            : earned.difficulty,
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
