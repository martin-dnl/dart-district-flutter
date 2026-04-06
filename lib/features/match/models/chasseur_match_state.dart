import 'match_model.dart';

enum ChasseurPhase { zoneSelection, playing }

class ChasseurPlayerState {
  const ChasseurPlayerState({
    required this.name,
    this.zone,
    this.lives = 1,
    this.isEliminated = false,
  });

  final String name;
  final int? zone;
  final int lives;
  final bool isEliminated;

  bool get isHunter => !isEliminated && lives >= 4;

  ChasseurPlayerState copyWith({
    String? name,
    int? zone,
    bool clearZone = false,
    int? lives,
    bool? isEliminated,
  }) {
    return ChasseurPlayerState(
      name: name ?? this.name,
      zone: clearZone ? null : (zone ?? this.zone),
      lives: lives ?? this.lives,
      isEliminated: isEliminated ?? this.isEliminated,
    );
  }
}

class ChasseurDart {
  const ChasseurDart({
    required this.zone,
    required this.multiplier,
    required this.livesChanged,
    this.targetPlayerIndex,
  });

  final int zone;
  final int multiplier;
  final int livesChanged;
  final int? targetPlayerIndex;
}

class ChasseurRoundEntry {
  const ChasseurRoundEntry({
    required this.playerIndex,
    required this.round,
    required this.darts,
  });

  final int playerIndex;
  final int round;
  final List<ChasseurDart> darts;
}

class ChasseurMatchState {
  const ChasseurMatchState({
    required this.id,
    required this.players,
    this.currentPlayerIndex = 0,
    this.currentDartInTurn = 0,
    this.currentRound = 1,
    this.status = MatchStatus.waiting,
    this.phase = ChasseurPhase.zoneSelection,
    this.roundHistory = const [],
    this.currentTurnDarts = const [],
    this.winnerIndex,
    this.lastFeedback,
  });

  final String id;
  final List<ChasseurPlayerState> players;
  final int currentPlayerIndex;
  final int currentDartInTurn;
  final int currentRound;
  final MatchStatus status;
  final ChasseurPhase phase;
  final List<ChasseurRoundEntry> roundHistory;
  final List<ChasseurDart> currentTurnDarts;
  final int? winnerIndex;
  final String? lastFeedback;

  int get activePlayers => players.where((p) => !p.isEliminated).length;

  ChasseurMatchState copyWith({
    List<ChasseurPlayerState>? players,
    int? currentPlayerIndex,
    int? currentDartInTurn,
    int? currentRound,
    MatchStatus? status,
    ChasseurPhase? phase,
    List<ChasseurRoundEntry>? roundHistory,
    List<ChasseurDart>? currentTurnDarts,
    int? winnerIndex,
    bool clearWinner = false,
    String? lastFeedback,
    bool clearLastFeedback = false,
  }) {
    return ChasseurMatchState(
      id: id,
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      currentDartInTurn: currentDartInTurn ?? this.currentDartInTurn,
      currentRound: currentRound ?? this.currentRound,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      roundHistory: roundHistory ?? this.roundHistory,
      currentTurnDarts: currentTurnDarts ?? this.currentTurnDarts,
      winnerIndex: clearWinner ? null : (winnerIndex ?? this.winnerIndex),
      lastFeedback: clearLastFeedback ? null : (lastFeedback ?? this.lastFeedback),
    );
  }
}
