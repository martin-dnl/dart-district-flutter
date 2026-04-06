import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/chasseur_match_state.dart';
import '../models/match_model.dart';

class ChasseurMatchController extends StateNotifier<ChasseurMatchState> {
  ChasseurMatchController()
      : super(
          ChasseurMatchState(
            id: const Uuid().v4(),
            players: const [
              ChasseurPlayerState(name: 'Joueur 1'),
              ChasseurPlayerState(name: 'Joueur 2'),
            ],
          ),
        );

  final List<ChasseurMatchState> _history = <ChasseurMatchState>[];

  void setupMatch({
    required List<String> playerNames,
    int startingPlayerIndex = 0,
  }) {
    final normalizedNames = playerNames.length >= 2
        ? playerNames
        : <String>[
            playerNames.isNotEmpty ? playerNames.first : 'Joueur 1',
            'Joueur 2',
          ];

    _history.clear();
    state = ChasseurMatchState(
      id: const Uuid().v4(),
      players: normalizedNames
          .map((name) => ChasseurPlayerState(name: name))
          .toList(growable: false),
      currentPlayerIndex: startingPlayerIndex.clamp(0, normalizedNames.length - 1),
      phase: ChasseurPhase.zoneSelection,
      status: MatchStatus.waiting,
    );
  }

  bool assignZone(int playerIndex, int zone) {
    if (playerIndex < 0 || playerIndex >= state.players.length) {
      return false;
    }
    if (!_isAllowedZone(zone)) {
      return false;
    }

    final alreadyUsed = state.players.asMap().entries.any((entry) {
      if (entry.key == playerIndex) {
        return false;
      }
      return entry.value.zone == zone;
    });
    if (alreadyUsed) {
      return false;
    }

    final players = List<ChasseurPlayerState>.from(state.players);
    players[playerIndex] = players[playerIndex].copyWith(zone: zone);

    final allAssigned = players.every((p) => p.zone != null);
    state = state.copyWith(
      players: players,
      phase: allAssigned ? ChasseurPhase.playing : ChasseurPhase.zoneSelection,
      status: allAssigned ? MatchStatus.inProgress : MatchStatus.waiting,
      currentDartInTurn: 0,
      currentTurnDarts: const [],
      clearLastFeedback: true,
    );
    return true;
  }

  void registerDart(int zone, int multiplier) {
    if (state.phase != ChasseurPhase.playing ||
        state.status != MatchStatus.inProgress ||
        state.currentDartInTurn > 2 ||
        multiplier < 1 ||
        multiplier > 3) {
      return;
    }

    _history.add(state);

    final players = List<ChasseurPlayerState>.from(state.players);
    final currentIndex = state.currentPlayerIndex;
    final currentPlayer = players[currentIndex];
    final shotLabel = switch (multiplier) {
      1 => 'S',
      2 => 'D',
      _ => 'T',
    };

    var livesChanged = 0;
    int? targetPlayerIndex;
    var feedback = '$shotLabel${zone == 25 ? 'Bull' : zone} - Miss';

    if (!_isAllowedZone(zone) || currentPlayer.isEliminated) {
      feedback = '$shotLabel${zone == 25 ? 'Bull' : zone} - Miss';
    } else if (zone == currentPlayer.zone) {
      final newLives = (currentPlayer.lives + multiplier).clamp(0, 4);
      livesChanged = newLives - currentPlayer.lives;
      players[currentIndex] = currentPlayer.copyWith(lives: newLives);
      feedback = '$shotLabel${zone == 25 ? 'Bull' : zone} - +$livesChanged vie';
    } else if (currentPlayer.isHunter) {
      final maybeTarget = players.asMap().entries.firstWhere(
            (entry) =>
                entry.key != currentIndex &&
                entry.value.zone == zone &&
                !entry.value.isEliminated,
            orElse: () => const MapEntry(-1, ChasseurPlayerState(name: 'none')),
          );

      if (maybeTarget.key != -1) {
        targetPlayerIndex = maybeTarget.key;
        final target = players[targetPlayerIndex];
        final nextLives = target.lives - multiplier;
        livesChanged = -multiplier;
        players[targetPlayerIndex] = target.copyWith(
          lives: nextLives,
          isEliminated: nextLives < 0,
        );
        feedback = '$shotLabel${zone == 25 ? 'Bull' : zone} - -$multiplier vie ${target.name}';
      }
    }

    final nextDarts = [
      ...state.currentTurnDarts,
      ChasseurDart(
        zone: zone,
        multiplier: multiplier,
        livesChanged: livesChanged,
        targetPlayerIndex: targetPlayerIndex,
      ),
    ];

    if (nextDarts.length < 3) {
      state = state.copyWith(
        players: players,
        currentTurnDarts: nextDarts,
        currentDartInTurn: nextDarts.length,
        lastFeedback: feedback,
      );
      return;
    }

    final roundHistory = [
      ...state.roundHistory,
      ChasseurRoundEntry(
        playerIndex: currentIndex,
        round: state.currentRound,
        darts: nextDarts,
      ),
    ];

    if (players.where((p) => !p.isEliminated).length <= 1) {
      final winner = players.indexWhere((p) => !p.isEliminated);
      state = state.copyWith(
        players: players,
        roundHistory: roundHistory,
        currentTurnDarts: const [],
        currentDartInTurn: 0,
        status: MatchStatus.finished,
        winnerIndex: winner >= 0 ? winner : null,
        lastFeedback: feedback,
      );
      return;
    }

    final nextPlayer = _nextActivePlayer(players, currentIndex);
    final nextRound = nextPlayer <= currentIndex
        ? state.currentRound + 1
        : state.currentRound;

    state = state.copyWith(
      players: players,
      roundHistory: roundHistory,
      currentTurnDarts: const [],
      currentDartInTurn: 0,
      currentPlayerIndex: nextPlayer,
      currentRound: nextRound,
      lastFeedback: feedback,
    );
  }

  void undoLastDart() {
    if (_history.isEmpty) {
      return;
    }
    state = _history.removeLast();
  }

  int _nextActivePlayer(List<ChasseurPlayerState> players, int currentIndex) {
    var next = (currentIndex + 1) % players.length;
    while (players[next].isEliminated) {
      next = (next + 1) % players.length;
    }
    return next;
  }

  bool _isAllowedZone(int zone) {
    return zone == 25 || (zone >= 1 && zone <= 20);
  }
}

final chasseurMatchControllerProvider =
    StateNotifierProvider<ChasseurMatchController, ChasseurMatchState>((ref) {
  return ChasseurMatchController();
});
