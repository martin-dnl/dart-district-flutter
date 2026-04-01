import 'package:flutter_riverpod/flutter_riverpod.dart';

final myActiveTournamentsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return const <Map<String, dynamic>>[];
});
