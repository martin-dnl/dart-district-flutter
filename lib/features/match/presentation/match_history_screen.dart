import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/network/api_providers.dart';
import '../../auth/controller/auth_controller.dart';
import '../models/recent_match_summary.dart';

class MatchHistoryScreen extends ConsumerStatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  ConsumerState<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends ConsumerState<MatchHistoryScreen> {
  static const int _pageSize = 10;

  final List<RecentMatchSummary> _matches = <RecentMatchSummary>[];
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
                RecentMatchSummary.fromApi(raw, currentUserId: currentUserId),
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
        _error = 'Impossible de charger l\'historique';
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
        title: const Text('Historique des matchs'),
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
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      itemCount: _matches.length,
                      itemBuilder: (context, index) {
                        final match = _matches[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () =>
                                context.push('/match/${match.id}/report'),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.stroke),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      match.opponentName,
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    match.setsScore,
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: match.won
                                          ? AppColors.success.withValues(
                                              alpha: 0.18,
                                            )
                                          : AppColors.error.withValues(
                                              alpha: 0.18,
                                            ),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(
                                      match.won ? 'V' : 'D',
                                      style: GoogleFonts.manrope(
                                        color: match.won
                                            ? AppColors.success
                                            : AppColors.error,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_hasMore)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ElevatedButton(
                        onPressed: _isLoadingMore ? null : _loadMore,
                        child: Text(
                          _isLoadingMore ? 'Chargement...' : 'Voir plus',
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
