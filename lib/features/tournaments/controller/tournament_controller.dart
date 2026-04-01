import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tournament_service.dart';
import '../models/bracket_match_model.dart';
import '../models/pool_model.dart';
import '../models/tournament_model.dart';

final tournamentsListProvider = FutureProvider<List<TournamentModel>>((ref) {
  return ref.read(tournamentServiceProvider).listTournaments();
});

final tournamentDetailProvider =
    FutureProvider.family<TournamentDetailModel, String>((ref, id) {
      return ref.read(tournamentServiceProvider).fetchDetail(id);
    });

final tournamentPoolsProvider = FutureProvider.family<List<PoolModel>, String>((
  ref,
  tournamentId,
) {
  return ref.read(tournamentServiceProvider).fetchPools(tournamentId);
});

final tournamentBracketProvider =
    FutureProvider.family<List<BracketMatchModel>, String>((ref, tournamentId) {
      return ref.read(tournamentServiceProvider).fetchBracket(tournamentId);
    });
