import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../auth/controller/auth_controller.dart';
import '../../match/models/recent_match_summary.dart';

final recentRankedMatchesProvider = FutureProvider<List<RecentMatchSummary>>((
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
            RecentMatchSummary.fromApi(match, currentUserId: currentUserId),
      )
      .toList();
});
