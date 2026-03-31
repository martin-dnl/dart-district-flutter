import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GameMode { x01_301, x01_501, x01_701, cricket, chasseur }

enum FinishType { doubleOut, singleOut, masterOut }

class GameConfig {
  final GameMode mode;
  final FinishType finishType;
  final int legsPerSet;
  final int setsToWin;
  final List<String> playerNames;

  const GameConfig({
    this.mode = GameMode.x01_501,
    this.finishType = FinishType.doubleOut,
    this.legsPerSet = 3,
    this.setsToWin = 1,
    this.playerNames = const ['Joueur 1', 'Joueur 2'],
  });

  int get startingScore {
    switch (mode) {
      case GameMode.x01_301:
        return 301;
      case GameMode.x01_501:
        return 501;
      case GameMode.x01_701:
        return 701;
      default:
        return 0;
    }
  }

  String get modeLabel {
    switch (mode) {
      case GameMode.x01_301:
        return '301';
      case GameMode.x01_501:
        return '501';
      case GameMode.x01_701:
        return '701';
      case GameMode.cricket:
        return 'Cricket';
      case GameMode.chasseur:
        return 'Chasseur';
    }
  }

  GameConfig copyWith({
    GameMode? mode,
    FinishType? finishType,
    int? legsPerSet,
    int? setsToWin,
    List<String>? playerNames,
  }) {
    return GameConfig(
      mode: mode ?? this.mode,
      finishType: finishType ?? this.finishType,
      legsPerSet: legsPerSet ?? this.legsPerSet,
      setsToWin: setsToWin ?? this.setsToWin,
      playerNames: playerNames ?? this.playerNames,
    );
  }
}

class PlayController extends StateNotifier<GameConfig> {
  PlayController() : super(const GameConfig());

  void setMode(GameMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setFinishType(FinishType type) {
    state = state.copyWith(finishType: type);
  }

  void setLegsPerSet(int legs) {
    state = state.copyWith(legsPerSet: legs);
  }

  void setSetsToWin(int sets) {
    state = state.copyWith(setsToWin: sets);
  }

  void setPlayerNames(List<String> names) {
    state = state.copyWith(playerNames: names);
  }
}

final playControllerProvider =
    StateNotifierProvider<PlayController, GameConfig>((ref) {
  return PlayController();
});
