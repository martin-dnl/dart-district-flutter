class MatchModel {
  final String id;
  final String mode;
  final int startingScore;
  final List<PlayerMatch> players;
  final int startingPlayerIndex;
  final int currentPlayerIndex;
  final int currentRound;
  final int currentLeg;
  final int currentSet;
  final MatchStatus status;
  final List<RoundScore> roundHistory;
  final String? inviterId; // ID of user who invited
  final String? inviteeId; // ID of invited user
  final InvitationStatus? invitationStatus;
  final DateTime? invitationCreatedAt;
  final int setsToWin;
  final int legsPerSet;
  final String finishType; // 'doubleOut', 'singleOut', 'masterOut'
  final bool isRanked;
  final bool isTerritorial;
  final int? abandonedByIndex;

  const MatchModel({
    required this.id,
    required this.mode,
    required this.startingScore,
    required this.players,
    this.startingPlayerIndex = 0,
    this.currentPlayerIndex = 0,
    this.currentRound = 1,
    this.currentLeg = 1,
    this.currentSet = 1,
    this.status = MatchStatus.inProgress,
    this.roundHistory = const [],
    this.inviterId,
    this.inviteeId,
    this.invitationStatus,
    this.invitationCreatedAt,
    this.setsToWin = 1,
    this.legsPerSet = 3,
    this.finishType = 'doubleOut',
    this.isRanked = true,
    this.isTerritorial = false,
    this.abandonedByIndex,
  });

  MatchModel copyWith({
    List<PlayerMatch>? players,
    int? startingPlayerIndex,
    int? currentPlayerIndex,
    int? currentRound,
    int? currentLeg,
    int? currentSet,
    MatchStatus? status,
    List<RoundScore>? roundHistory,
    String? inviterId,
    String? inviteeId,
    InvitationStatus? invitationStatus,
    DateTime? invitationCreatedAt,
    int? setsToWin,
    int? legsPerSet,
    String? finishType,
    bool? isRanked,
    bool? isTerritorial,
    int? abandonedByIndex,
  }) {
    return MatchModel(
      id: id,
      mode: mode,
      startingScore: startingScore,
      players: players ?? this.players,
      startingPlayerIndex: startingPlayerIndex ?? this.startingPlayerIndex,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      currentRound: currentRound ?? this.currentRound,
      currentLeg: currentLeg ?? this.currentLeg,
      currentSet: currentSet ?? this.currentSet,
      status: status ?? this.status,
      roundHistory: roundHistory ?? this.roundHistory,
      inviterId: inviterId ?? this.inviterId,
      inviteeId: inviteeId ?? this.inviteeId,
      invitationStatus: invitationStatus ?? this.invitationStatus,
      invitationCreatedAt: invitationCreatedAt ?? this.invitationCreatedAt,
      setsToWin: setsToWin ?? this.setsToWin,
      legsPerSet: legsPerSet ?? this.legsPerSet,
      finishType: finishType ?? this.finishType,
      isRanked: isRanked ?? this.isRanked,
      isTerritorial: isTerritorial ?? this.isTerritorial,
      abandonedByIndex: abandonedByIndex ?? this.abandonedByIndex,
    );
  }
}

class PlayerMatch {
  final String name;
  final int score;
  final int legsWon;
  final int setsWon;
  final List<int> throwScores;
  final double average;
  final int doublesAttempted;
  final int doublesHit;

  const PlayerMatch({
    required this.name,
    this.score = 0,
    this.legsWon = 0,
    this.setsWon = 0,
    this.throwScores = const [],
    this.average = 0.0,
    this.doublesAttempted = 0,
    this.doublesHit = 0,
  });

  int get totalDartsThrown => throwScores.length * 3;

  PlayerMatch copyWith({
    int? score,
    int? legsWon,
    int? setsWon,
    List<int>? throwScores,
    double? average,
    int? doublesAttempted,
    int? doublesHit,
  }) {
    return PlayerMatch(
      name: name,
      score: score ?? this.score,
      legsWon: legsWon ?? this.legsWon,
      setsWon: setsWon ?? this.setsWon,
      throwScores: throwScores ?? this.throwScores,
      average: average ?? this.average,
      doublesAttempted: doublesAttempted ?? this.doublesAttempted,
      doublesHit: doublesHit ?? this.doublesHit,
    );
  }
}

class RoundScore {
  final int playerIndex;
  final int round;
  final List<int> darts; // 3 darts per turn
  final int total;
  final bool isBust;
  final int doublesAttempted;

  const RoundScore({
    required this.playerIndex,
    required this.round,
    required this.darts,
    required this.total,
    this.isBust = false,
    this.doublesAttempted = 0,
  });
}

enum MatchStatus { waiting, inProgress, finished }

enum InvitationStatus { pending, accepted, refused }
