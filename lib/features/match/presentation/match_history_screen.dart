import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/translation_service.dart';
import '../../../core/network/api_providers.dart';
import '../../../shared/models/match_history_summary.dart';
import '../../../shared/widgets/match_history_list.dart';
import '../../auth/controller/auth_controller.dart';

class MatchHistoryScreen extends ConsumerStatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  ConsumerState<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends ConsumerState<MatchHistoryScreen> {
  static const int _pageSize = 10;

  final List<MatchHistorySummary> _matches = <MatchHistorySummary>[];
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isInitialLoading = true;
      _error = null;
      _matches.clear();
      _offset = 0;
      _hasMore = true;
    });

    await _loadMore();

    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final currentUserId = ref.read(currentUserProvider)?.id ?? '';

      final response = await api.get<Map<String, dynamic>>(
        '/matches/me',
        queryParameters: {
          'status': 'completed',
          'limit': '$_pageSize',
          'offset': '$_offset',
        },
      );

      final rows =
          (response.data?['data'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList();

      final nextBatch = rows
          .map(
            (raw) =>
                MatchHistorySummary.fromApi(raw, currentUserId: currentUserId),
          )
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _matches.addAll(nextBatch);
        _offset = _matches.length;
        _hasMore = nextBatch.length == _pageSize;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = t(
          'SCREEN.MATCH.HISTORY.LOAD_ERROR',
          fallback: 'Impossible de charger l\'historique',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          t('SCREEN.MATCH.HISTORY.TITLE', fallback: 'Historique des matchs'),
        ),
        backgroundColor: AppColors.background,
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(gradient: AppColors.pageGradient),
              child: Column(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        style: GoogleFonts.manrope(color: AppColors.error),
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: MatchHistoryList(
                        matches: _matches,
                        onMatchTap: (matchId) =>
                            context.push('/match/$matchId/report'),
                      ),
                    ),
                  ),
                  if (_hasMore)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ElevatedButton(
                        onPressed: _isLoadingMore ? null : _loadMore,
                        child: Text(
                          _isLoadingMore
                              ? t('COMMON.LOADING', fallback: 'Chargement...')
                              : t('COMMON.SEE_MORE', fallback: 'Voir plus'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
