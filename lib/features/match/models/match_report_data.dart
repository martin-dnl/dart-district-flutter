import 'match_model.dart';
import '../../../shared/models/dartboard_heatmap_models.dart';

class MatchReportData {
  const MatchReportData({
    required this.matchId,
    required this.mode,
    required this.player1,
    required this.player2,
    required this.setsScore,
    required this.winnerIndex,
    required this.wasAbandoned,
    required this.playedAt,
    required this.timeline,
  });

  final String matchId;
  final String mode;
  final PlayerReportStats player1;
  final PlayerReportStats player2;
  final String setsScore;
  final int winnerIndex;
  final bool wasAbandoned;
  final DateTime playedAt;
  final List<LegResult> timeline;

  factory MatchReportData.fromApi(Map<String, dynamic> raw) {
    final players = (raw['players'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();

    final p1Raw = players.isNotEmpty ? players[0] : const <String, dynamic>{};
    final p2Raw = players.length > 1 ? players[1] : const <String, dynamic>{};

    final finalSets =
        (raw['final_sets'] as List<dynamic>? ?? const <dynamic>[]);
    final p1Sets = finalSets.isNotEmpty
        ? _toInt(finalSets[0])
        : _toInt(p1Raw['sets_won']);
    final p2Sets = finalSets.length > 1
        ? _toInt(finalSets[1])
        : _toInt(p2Raw['sets_won']);

    final computedWinner = p1Sets == p2Sets
        ? (_toDouble(p1Raw['avg_score']) >= _toDouble(p2Raw['avg_score'])
              ? 0
              : 1)
        : (p1Sets > p2Sets ? 0 : 1);

    final timeline = (raw['timeline'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(LegResult.fromApi)
        .toList();

    final abandonedByName = (raw['abandoned_by_username'] ?? '').toString();
    final wasAbandoned =
        abandonedByName.isNotEmpty || raw['was_abandoned'] == true;

    return MatchReportData(
      matchId: (raw['match_id'] ?? raw['id'] ?? '').toString(),
      mode: (raw['mode'] ?? '501').toString(),
      player1: PlayerReportStats.fromApi(p1Raw),
      player2: PlayerReportStats.fromApi(p2Raw),
      setsScore: '$p1Sets - $p2Sets',
      winnerIndex: computedWinner,
      wasAbandoned: wasAbandoned,
      playedAt:
          DateTime.tryParse(
            (raw['played_at'] ?? raw['completed_at'] ?? raw['created_at'] ?? '')
                .toString(),
          ) ??
          DateTime.now(),
      timeline: wasAbandoned && abandonedByName.isNotEmpty
          ? [
              ...timeline,
              LegResult(
                setNumber: 0,
                legNumber: 0,
                winnerIndex: computedWinner,
                dartsToFinish: 0,
                winnerName: abandonedByName,
                isAbandonEvent: true,
              ),
            ]
          : timeline,
    );
  }

  factory MatchReportData.fromLocalMatch(MatchModel match) {
    final players = match.players;
    final p1 = players.isNotEmpty
        ? players[0]
        : const PlayerMatch(name: 'Joueur 1');
    final p2 = players.length > 1
        ? players[1]
        : const PlayerMatch(name: 'Joueur 2');

    final winnerIndex = p1.setsWon == p2.setsWon
        ? (p1.score <= p2.score ? 0 : 1)
        : (p1.setsWon > p2.setsWon ? 0 : 1);
    final p1Positions = match.roundHistory
        .where((round) => round.playerIndex == 0)
        .expand((round) => round.dartPositions)
        .map(
          (position) => DartboardHeatHit(
            x: position.x,
            y: position.y,
            score: position.score,
            label: position.label,
          ),
        )
        .toList(growable: false);
    final p2Positions = match.roundHistory
        .where((round) => round.playerIndex == 1)
        .expand((round) => round.dartPositions)
        .map(
          (position) => DartboardHeatHit(
            x: position.x,
            y: position.y,
            score: position.score,
            label: position.label,
          ),
        )
        .toList(growable: false);

    return MatchReportData(
      matchId: match.id,
      mode: match.mode,
      player1: PlayerReportStats.fromLocalPlayer(
        p1,
        dartPositions: p1Positions,
      ),
      player2: PlayerReportStats.fromLocalPlayer(
        p2,
        dartPositions: p2Positions,
      ),
      setsScore: '${p1.setsWon} - ${p2.setsWon}',
      winnerIndex: winnerIndex,
      wasAbandoned: match.abandonedByIndex != null,
      playedAt: DateTime.now(),
      timeline: _timelineFromLocalMatch(match, winnerIndex),
    );
  }

  static List<LegResult> _timelineFromLocalMatch(
    MatchModel match,
    int winnerIndex,
  ) {
    final results = <LegResult>[];
    int setNumber = 1;
    int legNumber = 1;

    for (final round in match.roundHistory) {
      final player = match.players[round.playerIndex];
      if (round.isBust) {
        continue;
      }
      if (player.score == 0 || round.total == player.score) {
        results.add(
          LegResult(
            setNumber: setNumber,
            legNumber: legNumber,
            winnerIndex: round.playerIndex,
            dartsToFinish: 3,
          ),
        );
        legNumber += 1;
        if (legNumber > match.legsPerSet) {
          setNumber += 1;
          legNumber = 1;
        }
      }
    }

    if (match.abandonedByIndex != null) {
      results.add(
        LegResult(
          setNumber: 0,
          legNumber: 0,
          winnerIndex: winnerIndex,
          dartsToFinish: 0,
          winnerName: match.players[match.abandonedByIndex!].name,
          isAbandonEvent: true,
        ),
      );
    }

    return results;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

class PlayerReportStats {
  const PlayerReportStats({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.average,
    required this.bestLegAvg,
    required this.checkoutRate,
    required this.count180,
    required this.count140Plus,
    required this.count100Plus,
    required this.doublesAttempted,
    required this.doublesHit,
    required this.totalDarts,
    this.dartPositions = const [],
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final double average;
  final double bestLegAvg;
  final double checkoutRate;
  final int count180;
  final int count140Plus;
  final int count100Plus;
  final int doublesAttempted;
  final int doublesHit;
  final int totalDarts;
  final List<DartboardHeatHit> dartPositions;

  factory PlayerReportStats.fromApi(Map<String, dynamic> raw) {
    return PlayerReportStats(
      userId: (raw['user_id'] ?? '').toString(),
      name: (raw['username'] ?? raw['name'] ?? 'Joueur').toString(),
      avatarUrl: raw['avatar_url']?.toString(),
      average: _toDouble(raw['avg_score']),
      bestLegAvg: _toDouble(raw['highest_checkout']),
      checkoutRate: _toDouble(raw['checkout_rate']),
      count180: _toInt(raw['count_180']),
      count140Plus: _toInt(raw['count_140_plus']),
      count100Plus: _toInt(raw['count_100_plus']),
      doublesAttempted: _toInt(raw['checkout_attempts']),
      doublesHit: _toInt(raw['checkout_hits']),
      totalDarts: _toInt(raw['total_darts']),
      dartPositions:
          (raw['dart_positions'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(DartboardHeatHit.fromJson)
              .where((hit) => hit.hasValidPosition)
              .toList(growable: false),
    );
  }

  factory PlayerReportStats.fromLocalPlayer(
    PlayerMatch player, {
    List<DartboardHeatHit> dartPositions = const [],
  }) {
    final attempts = player.doublesAttempted;
    final hits = player.doublesHit;
    return PlayerReportStats(
      userId: '',
      name: player.name,
      avatarUrl: null,
      average: player.average,
      bestLegAvg: player.average,
      checkoutRate: attempts > 0 ? (hits / attempts) * 100 : 0,
      count180: player.throwScores.where((s) => s == 180).length,
      count140Plus: player.throwScores.where((s) => s >= 140).length,
      count100Plus: player.throwScores.where((s) => s >= 100).length,
      doublesAttempted: attempts,
      doublesHit: hits,
      totalDarts: player.totalDartsThrown,
      dartPositions: dartPositions,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

class LegResult {
  const LegResult({
    required this.setNumber,
    required this.legNumber,
    required this.winnerIndex,
    required this.dartsToFinish,
    this.winnerName,
    this.isAbandonEvent = false,
  });

  final int setNumber;
  final int legNumber;
  final int winnerIndex;
  final int dartsToFinish;
  final String? winnerName;
  final bool isAbandonEvent;

  factory LegResult.fromApi(Map<String, dynamic> raw) {
    final winnerIdx = (raw['winner_index'] as num?)?.toInt() ?? 0;
    return LegResult(
      setNumber: (raw['set'] as num?)?.toInt() ?? 0,
      legNumber: (raw['leg'] as num?)?.toInt() ?? 0,
      winnerIndex: winnerIdx,
      dartsToFinish: (raw['darts_to_finish'] as num?)?.toInt() ?? 0,
      winnerName: raw['winner_username']?.toString(),
      isAbandonEvent: raw['event']?.toString() == 'abandon',
    );
  }
}
