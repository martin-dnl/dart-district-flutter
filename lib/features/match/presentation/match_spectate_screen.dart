import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/network/api_providers.dart';
import '../data/match_service.dart';
import '../data/match_spectate_realtime_service.dart';
import '../models/match_model.dart';
import '../widgets/round_details.dart';
import '../widgets/scoreboard.dart';

class MatchSpectateScreen extends ConsumerStatefulWidget {
  const MatchSpectateScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<MatchSpectateScreen> createState() =>
      _MatchSpectateScreenState();
}

class _MatchSpectateScreenState extends ConsumerState<MatchSpectateScreen> {
  MatchModel? _match;
  String? _error;
  bool _loading = true;

  MatchSpectateRealtimeService? _realtime;
  StreamSubscription<MatchModel>? _sub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final api = ref.read(apiClientProvider);
      final service = MatchService(api);
      final initial = await service.getMatch(widget.matchId);

      if (!mounted) {
        return;
      }

      setState(() {
        _match = initial;
        _loading = false;
      });

      final realtime = MatchSpectateRealtimeService(service);
      _realtime = realtime;
      await realtime.connect(widget.matchId);
      _sub = realtime.updates.listen((updated) {
        if (!mounted) {
          return;
        }
        setState(() {
          _match = updated;
        });
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Impossible de charger le match en direct.';
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _realtime?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final match = _match;
    if (match == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('LIVE')),
        body: Center(
          child: Text(
            _error ?? 'Match introuvable',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('LIVE · ${match.mode}'),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Spectateur',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Scoreboard(
              players: match.players,
              currentPlayerIndex: match.currentPlayerIndex,
              finishType: match.finishType,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Round ${match.currentRound}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    match.players[match.currentPlayerIndex].name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RoundDetails(
                roundHistory: match.roundHistory,
                players: match.players,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
