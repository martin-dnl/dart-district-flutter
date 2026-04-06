import 'match_model.dart';

const List<int> cricketZones = [20, 19, 18, 17, 16, 15, 25];

class CricketPlayerState {
  const CricketPlayerState({
    required this.name,
    this.score = 0,
    this.hits = const {20: 0, 19: 0, 18: 0, 17: 0, 16: 0, 15: 0, 25: 0},
    this.legsWon = 0,
    this.setsWon = 0,
  });

  final String name;
  final int score;
  final Map<int, int> hits;
  final int legsWon;
  final int setsWon;

  bool isClosed(int zone) => (hits[zone] ?? 0) >= 3;
  bool get allClosed => cricketZones.every(isClosed);

  CricketPlayerState copyWith({
    String? name,
    int? score,
    Map<int, int>? hits,
    int? legsWon,
    int? setsWon,
  }) {
    return CricketPlayerState(
      name: name ?? this.name,
      score: score ?? this.score,
      hits: hits ?? this.hits,
      legsWon: legsWon ?? this.legsWon,
      setsWon: setsWon ?? this.setsWon,
    );
  }
}

class CricketDart {
  const CricketDart({
    required this.zone,
    required this.multiplier,
    required this.hitsApplied,
    required this.pointsInflicted,
  });

  final int zone;
  final int multiplier;
  final int hitsApplied;
  final int pointsInflicted;
}

class CricketRoundEntry {
  const CricketRoundEntry({
    required this.playerIndex,
    required this.round,
    required this.darts,
  });

  final int playerIndex;
  final int round;
  final List<CricketDart> darts;
}

class CricketMatchState {
  const CricketMatchState({
    required this.id,
    required this.players,
    this.startingPlayerIndex = 0,
    this.currentPlayerIndex = 0,
    this.currentDartInTurn = 0,
    this.currentRound = 1,
    this.currentLeg = 1,
    this.currentSet = 1,
    this.setsToWin = 1,
    this.legsPerSet = 3,
    this.status = MatchStatus.waiting,
    this.roundHistory = const [],
    this.currentTurnDarts = const [],
    this.winnerIndex,
  });

  final String id;
  final List<CricketPlayerState> players;
  final int startingPlayerIndex;
  final int currentPlayerIndex;
  final int currentDartInTurn;
  final int currentRound;
  final int currentLeg;
  final int currentSet;
  final int setsToWin;
  final int legsPerSet;
  final MatchStatus status;
  final List<CricketRoundEntry> roundHistory;
  final List<CricketDart> currentTurnDarts;
  final int? winnerIndex;

  CricketMatchState copyWith({
    List<CricketPlayerState>? players,
    int? startingPlayerIndex,
    int? currentPlayerIndex,
    int? currentDartInTurn,
    int? currentRound,
    int? currentLeg,
    int? currentSet,
    int? setsToWin,
    int? legsPerSet,
    MatchStatus? status,
    List<CricketRoundEntry>? roundHistory,
    List<CricketDart>? currentTurnDarts,
    int? winnerIndex,
    bool clearWinner = false,
  }) {
    return CricketMatchState(
      id: id,
      players: players ?? this.players,
      startingPlayerIndex: startingPlayerIndex ?? this.startingPlayerIndex,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      currentDartInTurn: currentDartInTurn ?? this.currentDartInTurn,
      currentRound: currentRound ?? this.currentRound,
      currentLeg: currentLeg ?? this.currentLeg,
      currentSet: currentSet ?? this.currentSet,
      setsToWin: setsToWin ?? this.setsToWin,
      legsPerSet: legsPerSet ?? this.legsPerSet,
      status: status ?? this.status,
      roundHistory: roundHistory ?? this.roundHistory,
      currentTurnDarts: currentTurnDarts ?? this.currentTurnDarts,
      winnerIndex: clearWinner ? null : (winnerIndex ?? this.winnerIndex),
    );
  }
}
