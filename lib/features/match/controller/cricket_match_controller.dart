import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/cricket_match_state.dart';
import '../models/match_model.dart';

class CricketMatchController extends StateNotifier<CricketMatchState> {
  CricketMatchController()
      : super(
          CricketMatchState(
            id: const Uuid().v4(),
            players: const [
              CricketPlayerState(name: 'Joueur 1'),
              CricketPlayerState(name: 'Joueur 2'),
            ],
          ),
        );

  final List<CricketMatchState> _history = <CricketMatchState>[];

  void setupMatch({
    required List<String> playerNames,
    int setsToWin = 1,
    int legsPerSet = 3,
    int startingPlayerIndex = 0,
  }) {
    final normalizedNames = playerNames.length >= 2
        ? playerNames.take(2).toList(growable: false)
        : <String>[
            playerNames.isNotEmpty ? playerNames.first : 'Joueur 1',
            'Joueur 2',
          ];

    _history.clear();
    state = CricketMatchState(
      id: const Uuid().v4(),
      players: normalizedNames
          .map((name) => CricketPlayerState(name: name))
          .toList(growable: false),
      setsToWin: setsToWin,
      legsPerSet: legsPerSet,
      status: MatchStatus.inProgress,
      currentPlayerIndex: startingPlayerIndex.clamp(0, 1),
      startingPlayerIndex: startingPlayerIndex.clamp(0, 1),
    );
  }

  void loadRemoteMatch(MatchModel remoteMatch) {
    final names = remoteMatch.players.map((p) => p.name).toList(growable: false);
    setupMatch(
      playerNames: names.length >= 2 ? names : const ['Joueur 1', 'Joueur 2'],
      setsToWin: remoteMatch.setsToWin,
      legsPerSet: remoteMatch.legsPerSet,
      startingPlayerIndex: remoteMatch.startingPlayerIndex,
    );

    for (final round in remoteMatch.roundHistory) {
      if (round.playerIndex < 0 || round.playerIndex >= state.players.length) {
        continue;
      }
      final label = round.dartPositions.isNotEmpty
          ? (round.dartPositions.first.label ?? '')
          : '';
      final parsed = _parseRemoteCricketLabel(label);
      if (parsed == null) {
        continue;
      }
      registerDart(parsed.zone, parsed.multiplier);
    }

    _history.clear();
    state = state.copyWith(
      status: remoteMatch.status,
    );
  }

  ({int zone, int multiplier})? _parseRemoteCricketLabel(String raw) {
    final match = RegExp(r'^C:([-]?\d+):([1-3])$').firstMatch(raw);
    if (match == null) {
      return null;
    }
    final zone = int.tryParse(match.group(1) ?? '');
    final multiplier = int.tryParse(match.group(2) ?? '');
    if (zone == null || multiplier == null) {
      return null;
    }
    return (zone: zone, multiplier: multiplier);
  }

  void registerDart(int zone, int multiplier) {
    if (state.status != MatchStatus.inProgress) {
      return;
    }
    if (multiplier < 1 || multiplier > 3 || state.currentDartInTurn > 2) {
      return;
    }

    _history.add(state);

    final players = List<CricketPlayerState>.from(state.players);
    final currentIndex = state.currentPlayerIndex;
    final opponentIndex = currentIndex == 0 ? 1 : 0;
    var currentPlayer = players[currentIndex];
    var opponent = players[opponentIndex];

    final zoneValue = _zoneValue(zone);
    var hitsApplied = 0;
    var pointsInflicted = 0;

    if (zoneValue != null) {
      final currentHits = currentPlayer.hits[zoneValue] ?? 0;
      final touchesBeforeClose = (3 - currentHits).clamp(0, 3);
      hitsApplied = multiplier <= touchesBeforeClose ? multiplier : touchesBeforeClose;
      final touchesAfterClose = multiplier - hitsApplied;

      final updatedHits = Map<int, int>.from(currentPlayer.hits)
        ..[zoneValue] = (currentHits + multiplier).clamp(0, 6);
      currentPlayer = currentPlayer.copyWith(hits: updatedHits);

      if (touchesAfterClose > 0 && !opponent.isClosed(zoneValue)) {
        pointsInflicted = touchesAfterClose * zoneValue;
        opponent = opponent.copyWith(score: opponent.score + pointsInflicted);
      }
    } else {
      zone = -1;
    }

    players[currentIndex] = currentPlayer;
    players[opponentIndex] = opponent;

    final nextTurnDarts = [
      ...state.currentTurnDarts,
      CricketDart(
        zone: zone,
        multiplier: multiplier,
        hitsApplied: hitsApplied,
        pointsInflicted: pointsInflicted,
      ),
    ];

    if (nextTurnDarts.length < 3) {
      state = state.copyWith(
        players: players,
        currentDartInTurn: nextTurnDarts.length,
        currentTurnDarts: nextTurnDarts,
      );
      return;
    }

    final roundHistory = [
      ...state.roundHistory,
      CricketRoundEntry(
        playerIndex: currentIndex,
        round: state.currentRound,
        darts: nextTurnDarts,
      ),
    ];

    if (_isLegWinner(players, currentIndex, opponentIndex)) {
      _handleLegWin(players, currentIndex, roundHistory);
      return;
    }

    final nextStarter = state.startingPlayerIndex;
    final nextPlayer = currentIndex == 0 ? 1 : 0;
    final nextRound = nextPlayer == nextStarter
        ? state.currentRound + 1
        : state.currentRound;

    state = state.copyWith(
      players: players,
      roundHistory: roundHistory,
      currentTurnDarts: const [],
      currentDartInTurn: 0,
      currentPlayerIndex: nextPlayer,
      currentRound: nextRound,
    );
  }

  void undoLastDart() {
    if (_history.isEmpty) {
      return;
    }
    state = _history.removeLast();
  }

  void undoRound() {
    if (_history.isEmpty) {
      return;
    }

    final targetRound = state.currentRound;
    while (_history.isNotEmpty && state.currentRound == targetRound) {
      state = _history.removeLast();
    }
  }

  void abandonMatch(int abandoningPlayerIndex) {
    if (state.status != MatchStatus.inProgress) {
      return;
    }
    if (abandoningPlayerIndex < 0 || abandoningPlayerIndex >= state.players.length) {
      return;
    }

    final winnerIndex = abandoningPlayerIndex == 0 ? 1 : 0;
    final players = List<CricketPlayerState>.from(state.players);
    if (winnerIndex >= 0 && winnerIndex < players.length) {
      players[winnerIndex] = players[winnerIndex].copyWith(setsWon: state.setsToWin);
    }

    state = state.copyWith(
      players: players,
      status: MatchStatus.finished,
      winnerIndex: winnerIndex,
    );
  }

  bool _isLegWinner(List<CricketPlayerState> players, int currentIndex, int opponentIndex) {
    final player = players[currentIndex];
    final opponent = players[opponentIndex];
    return player.allClosed && player.score <= opponent.score;
  }

  void _handleLegWin(
    List<CricketPlayerState> players,
    int winnerIndex,
    List<CricketRoundEntry> roundHistory,
  ) {
    final updatedPlayers = List<CricketPlayerState>.from(players);
    final legWinner = updatedPlayers[winnerIndex];

    updatedPlayers[winnerIndex] = legWinner.copyWith(legsWon: legWinner.legsWon + 1);

    final legsToWin = (state.legsPerSet / 2).ceil();
    final legCount = updatedPlayers[winnerIndex].legsWon;

    if (legCount >= legsToWin) {
      final setWinner = updatedPlayers[winnerIndex];
      updatedPlayers[winnerIndex] = setWinner.copyWith(
        setsWon: setWinner.setsWon + 1,
        legsWon: 0,
      );

      for (var i = 0; i < updatedPlayers.length; i++) {
        if (i == winnerIndex) {
          continue;
        }
        updatedPlayers[i] = updatedPlayers[i].copyWith(legsWon: 0);
      }

      if (updatedPlayers[winnerIndex].setsWon >= state.setsToWin) {
        state = state.copyWith(
          players: updatedPlayers,
          roundHistory: roundHistory,
          currentTurnDarts: const [],
          currentDartInTurn: 0,
          status: MatchStatus.finished,
          winnerIndex: winnerIndex,
        );
        return;
      }

      final nextStarter = state.startingPlayerIndex == 0 ? 1 : 0;
      state = state.copyWith(
        players: _resetLegState(updatedPlayers),
        roundHistory: roundHistory,
        currentTurnDarts: const [],
        currentDartInTurn: 0,
        currentPlayerIndex: nextStarter,
        startingPlayerIndex: nextStarter,
        currentRound: 1,
        currentLeg: 1,
        currentSet: state.currentSet + 1,
      );
      return;
    }

    final nextStarter = state.startingPlayerIndex == 0 ? 1 : 0;
    state = state.copyWith(
      players: _resetLegState(updatedPlayers),
      roundHistory: roundHistory,
      currentTurnDarts: const [],
      currentDartInTurn: 0,
      currentPlayerIndex: nextStarter,
      startingPlayerIndex: nextStarter,
      currentRound: 1,
      currentLeg: state.currentLeg + 1,
    );
  }

  List<CricketPlayerState> _resetLegState(List<CricketPlayerState> players) {
    return players
        .map(
          (player) => player.copyWith(
            score: 0,
            hits: const {20: 0, 19: 0, 18: 0, 17: 0, 16: 0, 15: 0, 25: 0},
          ),
        )
        .toList(growable: false);
  }

  int? _zoneValue(int zone) {
    if (zone == 25) {
      return 25;
    }
    if (zone >= 15 && zone <= 20) {
      return zone;
    }
    return null;
  }
}

final cricketMatchControllerProvider =
    StateNotifierProvider<CricketMatchController, CricketMatchState>((ref) {
  return CricketMatchController();
});
