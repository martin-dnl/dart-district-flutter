import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../../shared/models/match_history_summary.dart';
import '../../auth/controller/auth_controller.dart';

final recentRankedMatchesProvider = FutureProvider<List<MatchHistorySummary>>((
  ref,
) async {
  final api = ref.read(apiClientProvider);
  final currentUserId = ref.read(currentUserProvider)?.id ?? '';

  final response = await api.get<Map<String, dynamic>>(
    '/matches/me',
    queryParameters: const {
      'ranked': 'true',
      'status': 'completed',
      'limit': '5',
    },
  );

  final data = (response.data?['data'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map<String, dynamic>>()
      .toList();

  return data
      .map(
        (match) =>
            MatchHistorySummary.fromApi(match, currentUserId: currentUserId),
      )
      .toList();
});
