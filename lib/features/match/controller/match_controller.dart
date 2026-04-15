import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/match_model.dart';

class MatchController extends StateNotifier<MatchModel> {
  MatchController()
    : super(
        MatchModel(
          id: const Uuid().v4(),
          mode: '501',
          startingScore: 501,
          players: const [
            PlayerMatch(name: 'Joueur 1', score: 501),
            PlayerMatch(name: 'Joueur 2', score: 501),
          ],
        ),
      );

  void setupMatch({
    required String mode,
    required int startingScore,
    required List<String> playerNames,
    int setsToWin = 1,
    int legsPerSet = 3,
    String finishType = 'doubleOut',
    int startingPlayerIndex = 0,
    bool isRanked = true,
    bool isTerritorial = false,
    String? inviterId,
    String? inviteeId,
  }) {
    state = MatchModel(
      id: const Uuid().v4(),
      mode: mode,
      startingScore: startingScore,
      players: [
        for (final name in playerNames)
          PlayerMatch(name: name, score: startingScore),
      ],
      startingPlayerIndex: startingPlayerIndex,
      currentPlayerIndex: startingPlayerIndex,
      status: MatchStatus.inProgress,
      setsToWin: setsToWin,
      legsPerSet: legsPerSet,
      finishType: finishType,
      isRanked: isRanked,
      isTerritorial: isTerritorial,
      inviterId: inviterId,
      inviteeId: inviteeId,
      invitationStatus: inviteeId != null ? InvitationStatus.pending : null,
    );
  }

  void submitScore(
    int score, {
    int? doublesAttempted,
    List<DartPosition>? dartPositions,
  }) {
    if (state.status != MatchStatus.inProgress) return;

    final players = List<PlayerMatch>.from(state.players);
    final currentPlayer = players[state.currentPlayerIndex];
    final newScore = currentPlayer.score - score;
    final bustOnOneRemaining =
      newScore == 1 && (_isDoubleOutMode() || _isMasterOutMode());

    if (bustOnOneRemaining) {
      final roundHistory = [
        ...state.roundHistory,
        RoundScore(
          playerIndex: state.currentPlayerIndex,
          round: state.currentRound,
          darts: const [0],
          total: 0,
          isBust: true,
          dartPositions: dartPositions ?? const [],
        ),
      ];
      _applyTurnAdvance(players: players, roundHistory: roundHistory);
      return;
    }

    if (newScore < 0) {
      final roundHistory = [
        ...state.roundHistory,
        RoundScore(
          playerIndex: state.currentPlayerIndex,
          round: state.currentRound,
          darts: const [0],
          total: 0,
          isBust: true,
          dartPositions: dartPositions ?? const [],
        ),
      ];
      _applyTurnAdvance(players: players, roundHistory: roundHistory);
      return;
    }

    if (newScore == 0 && !_isCheckoutAllowed(dartPositions, doublesAttempted)) {
      final roundHistory = [
        ...state.roundHistory,
        RoundScore(
          playerIndex: state.currentPlayerIndex,
          round: state.currentRound,
          darts: const [0],
          total: 0,
          isBust: true,
          dartPositions: dartPositions ?? const [],
        ),
      ];
      _applyTurnAdvance(players: players, roundHistory: roundHistory);
      return;
    }

    if (newScore == 0 && (_isDoubleOutMode() || _isMasterOutMode())) {
      if (doublesAttempted == null ||
          doublesAttempted < 0 ||
          doublesAttempted > 3) {
        return;
      }
      players[state.currentPlayerIndex] = currentPlayer.copyWith(
        doublesAttempted: currentPlayer.doublesAttempted + doublesAttempted,
        doublesHit: currentPlayer.doublesHit + 1,
      );
    }

    final updatedThrows = [...currentPlayer.throwScores, score];

    final roundHistory = [
      ...state.roundHistory,
      RoundScore(
        playerIndex: state.currentPlayerIndex,
        round: state.currentRound,
        darts: [score],
        total: score,
        doublesAttempted:
          (newScore == 0 && (_isDoubleOutMode() || _isMasterOutMode()))
            ? (doublesAttempted ?? 0)
            : 0,
        dartPositions: dartPositions ?? const [],
      ),
    ];

    final avgPerRound = _computePlayerAverage(
      state.currentPlayerIndex,
      roundHistory,
    );

    players[state.currentPlayerIndex] = currentPlayer.copyWith(
      score: newScore,
      throwScores: updatedThrows,
      average: avgPerRound,
      doublesAttempted: players[state.currentPlayerIndex].doublesAttempted,
      doublesHit: players[state.currentPlayerIndex].doublesHit,
    );

    // Check if current player won the leg
    if (newScore == 0) {
      players[state.currentPlayerIndex] = players[state.currentPlayerIndex]
          .copyWith(legsWon: currentPlayer.legsWon + 1);

      final legsToWinSet = (state.legsPerSet / 2).ceil();

      // Check if current player won the set
      if (currentPlayer.legsWon + 1 >= legsToWinSet) {
        // Player wins the set
        players[state.currentPlayerIndex] = players[state.currentPlayerIndex]
            .copyWith(setsWon: currentPlayer.setsWon + 1);

        // Check if current player won the match
        if (currentPlayer.setsWon + 1 >= state.setsToWin) {
          // Match is finished
          state = state.copyWith(
            players: players,
            status: MatchStatus.finished,
            roundHistory: roundHistory,
          );
          return;
        }

        final nextStarter = _nextStartingPlayer();

        // Reset for next set
        for (var i = 0; i < players.length; i++) {
          players[i] = players[i].copyWith(
            score: state.startingScore,
            legsWon: 0,
          );
        }

        state = state.copyWith(
          players: players,
          startingPlayerIndex: nextStarter,
          currentPlayerIndex: nextStarter,
          currentRound: 1,
          currentLeg: 1,
          currentSet: state.currentSet + 1,
          roundHistory: roundHistory,
        );
        return;
      }

      // Reset scores for next leg in current set
      for (var i = 0; i < players.length; i++) {
        players[i] = players[i].copyWith(score: state.startingScore);
      }

      final nextStarter = _nextStartingPlayer();

      state = state.copyWith(
        players: players,
        startingPlayerIndex: nextStarter,
        currentPlayerIndex: nextStarter,
        currentRound: 1,
        currentLeg: state.currentLeg + 1,
        roundHistory: roundHistory,
      );
      return;
    }

    // Switch to next player
    final nextPlayer = (state.currentPlayerIndex + 1) % state.players.length;
    final nextRound = nextPlayer == 0
        ? state.currentRound + 1
        : state.currentRound;

    state = state.copyWith(
      players: players,
      currentPlayerIndex: nextPlayer,
      currentRound: nextRound,
      roundHistory: roundHistory,
    );
  }

  /// Determine next starting player (alternates between players)
  int _nextStartingPlayer() {
    return (state.startingPlayerIndex + 1) % state.players.length;
  }

  void loadMatch(MatchModel match) {
    state = match;
  }

  void acceptInvitation() {
    state = state.copyWith(
      invitationStatus: InvitationStatus.accepted,
      status: MatchStatus.inProgress,
    );
  }

  void refuseInvitation() {
    state = state.copyWith(
      invitationStatus: InvitationStatus.refused,
      status: MatchStatus.finished,
    );
  }

  void updateFromSocket(MatchModel remoteMatch) {
    state = remoteMatch;
  }

  void undoLastScore() {
    if (state.roundHistory.isEmpty) return;

    final lastRound = state.roundHistory.last;
    final players = List<PlayerMatch>.from(state.players);
    final player = players[lastRound.playerIndex];

    final updatedThrows = List<int>.from(player.throwScores);
    if (!lastRound.isBust && updatedThrows.isNotEmpty) {
      updatedThrows.removeLast();
    }

    players[lastRound.playerIndex] = player.copyWith(
      score: lastRound.isBust ? player.score : player.score + lastRound.total,
      throwScores: updatedThrows,
      doublesAttempted: (player.doublesAttempted - lastRound.doublesAttempted)
          .clamp(0, 1 << 31),
      doublesHit: (player.doublesHit - (lastRound.doublesAttempted > 0 ? 1 : 0))
          .clamp(0, 1 << 31),
    );

    final nextHistory = state.roundHistory.sublist(
      0,
      state.roundHistory.length - 1,
    );

    for (var i = 0; i < players.length; i++) {
      players[i] = players[i].copyWith(
        average: _computePlayerAverage(i, nextHistory),
      );
    }

    state = state.copyWith(
      players: players,
      currentPlayerIndex: lastRound.playerIndex,
      currentRound: lastRound.round,
      roundHistory: nextHistory,
    );
  }

  void endMatch() {
    state = state.copyWith(status: MatchStatus.finished);
  }

  void abandonMatch(int abandoningPlayerIndex) {
    if (state.status != MatchStatus.inProgress) {
      return;
    }
    if (abandoningPlayerIndex < 0 ||
        abandoningPlayerIndex >= state.players.length) {
      return;
    }

    final winnerIndex = abandoningPlayerIndex == 0 ? 1 : 0;
    final players = List<PlayerMatch>.from(state.players);
    if (winnerIndex >= 0 && winnerIndex < players.length) {
      players[winnerIndex] = players[winnerIndex].copyWith(
        setsWon: state.setsToWin,
      );
    }

    state = state.copyWith(
      status: MatchStatus.finished,
      players: players,
      abandonedByIndex: abandoningPlayerIndex,
    );
  }

  bool _isDoubleOutMode() {
    final normalized = state.finishType.toLowerCase();
    return normalized == 'doubleout' || normalized == 'double_out';
  }

  bool _isMasterOutMode() {
    final normalized = state.finishType.toLowerCase();
    return normalized == 'masterout' || normalized == 'master_out';
  }

  bool _isCheckoutAllowed(
    List<DartPosition>? dartPositions,
    int? doublesAttempted,
  ) {
    if (_isDoubleOutMode()) {
      final lastLabel = dartPositions == null || dartPositions.isEmpty
          ? null
          : dartPositions.last.label?.toUpperCase();
      if (lastLabel != null && lastLabel.isNotEmpty) {
        return lastLabel.startsWith('D');
      }
      return (doublesAttempted ?? 0) > 0;
    }

    if (_isMasterOutMode()) {
      final lastLabel = dartPositions == null || dartPositions.isEmpty
          ? null
          : dartPositions.last.label?.toUpperCase();
      if (lastLabel != null && lastLabel.isNotEmpty) {
        return lastLabel.startsWith('D') || lastLabel.startsWith('T');
      }
      return true;
    }

    return true;
  }

  double _computePlayerAverage(int playerIndex, List<RoundScore> history) {
    final validRounds = history
        .where((r) => r.playerIndex == playerIndex && !r.isBust)
        .toList();
    if (validRounds.isEmpty) {
      return 0.0;
    }

    final total = validRounds.fold<int>(0, (sum, r) => sum + r.total);
    return total / validRounds.length;
  }

  void _applyTurnAdvance({
    required List<PlayerMatch> players,
    required List<RoundScore> roundHistory,
  }) {
    final nextPlayer = (state.currentPlayerIndex + 1) % state.players.length;
    final nextRound = nextPlayer == 0
        ? state.currentRound + 1
        : state.currentRound;

    state = state.copyWith(
      players: players,
      currentPlayerIndex: nextPlayer,
      currentRound: nextRound,
      roundHistory: roundHistory,
    );
  }
}

final matchControllerProvider =
    StateNotifierProvider<MatchController, MatchModel>((ref) {
      return MatchController();
    });
