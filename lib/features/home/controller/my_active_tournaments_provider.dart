import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tournaments/data/tournament_service.dart';

final myActiveTournamentsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final service = ref.read(tournamentServiceProvider);
  final tournaments = await service.listTournaments();

  final active =
      tournaments
          .where((t) => t.currentPhase.toLowerCase() != 'finished')
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  return active
      .map(
        (t) => <String, dynamic>{
          'id': t.id,
          'name': t.name,
          'is_territorial': t.format == 'territorial',
          'scheduled_at_label':
              '${t.scheduledAt.day.toString().padLeft(2, '0')}/${t.scheduledAt.month.toString().padLeft(2, '0')} ${t.scheduledAt.hour.toString().padLeft(2, '0')}:${t.scheduledAt.minute.toString().padLeft(2, '0')}',
          'enrolled_players': t.enrolledPlayers,
          'max_players': t.maxPlayers,
        },
      )
      .toList();
});
