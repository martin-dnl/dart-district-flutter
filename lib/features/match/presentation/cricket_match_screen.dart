import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../controller/cricket_match_controller.dart';
import '../models/cricket_match_state.dart';
import '../models/match_model.dart';

class CricketMatchScreen extends ConsumerStatefulWidget {
  const CricketMatchScreen({super.key});

  @override
  ConsumerState<CricketMatchScreen> createState() => _CricketMatchScreenState();
}

class _CricketMatchScreenState extends ConsumerState<CricketMatchScreen> {
  bool _endDialogShown = false;
  Timer? _pendingShotTimer;
  int? _pendingZone;
  int _pendingMultiplier = 0;
  String? _shotBadge;

  @override
  void dispose() {
    _pendingShotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CricketMatchState>(cricketMatchControllerProvider, (prev, next) {
      if (!_endDialogShown && next.status == MatchStatus.finished && mounted) {
        _endDialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _showEndDialog(next);
        });
      }
    });

    final state = ref.watch(cricketMatchControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cricket'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _CricketScoreboard(state: state),
            _TurnIndicator(state: state),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _CricketGrid(
                  state: state,
                  onTapZone: _onTapZone,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _shotBadge == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey<String>(_shotBadge!),
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Text(
                        _shotBadge!,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _pendingShotTimer?.cancel();
                        _pendingShotTimer = null;
                        _pendingZone = null;
                        _pendingMultiplier = 0;
                        setState(() => _shotBadge = null);
                        ref.read(cricketMatchControllerProvider.notifier).undoLastDart();
                      },
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.go(AppRoutes.play),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Quitter'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTapZone(int zone) {
    final state = ref.read(cricketMatchControllerProvider);
    if (state.status != MatchStatus.inProgress) {
      return;
    }

    if (_pendingZone == zone) {
      _pendingMultiplier = (_pendingMultiplier + 1).clamp(1, 3);
    } else {
      _commitPendingShot();
      _pendingZone = zone;
      _pendingMultiplier = 1;
    }

    _pendingShotTimer?.cancel();
    _pendingShotTimer = Timer(const Duration(milliseconds: 520), _commitPendingShot);

    setState(() {
      _shotBadge = switch (_pendingMultiplier) {
        1 => 'S$zone',
        2 => 'D$zone',
        _ => 'T$zone',
      };
    });
  }

  void _commitPendingShot() {
    final zone = _pendingZone;
    final multiplier = _pendingMultiplier;
    if (zone == null || multiplier < 1) {
      return;
    }

    _pendingShotTimer?.cancel();
    _pendingShotTimer = null;
    _pendingZone = null;
    _pendingMultiplier = 0;

    ref.read(cricketMatchControllerProvider.notifier).registerDart(zone, multiplier);

    Future<void>.delayed(const Duration(milliseconds: 380), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _shotBadge = null;
      });
    });
  }

  Future<void> _showEndDialog(CricketMatchState state) async {
    final winner = state.winnerIndex != null ? state.players[state.winnerIndex!] : null;
    final p1Closed = cricketZones.where((z) => state.players[0].isClosed(z)).length;
    final p2Closed = cricketZones.where((z) => state.players[1].isClosed(z)).length;
    final recent = state.roundHistory.reversed.take(4).toList(growable: false);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Match termine',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  winner == null
                      ? 'Fin de partie.'
                      : '${winner.name} remporte la partie de Cricket.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Text(
                  '${state.players[0].name}: $p1Closed/7 zones fermees - ${state.players[0].score} pts',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${state.players[1].name}: $p2Closed/7 zones fermees - ${state.players[1].score} pts',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                ),
                if (recent.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Derniers tours',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final round in recent)
                    Text(
                      'R${round.round} · ${state.players[round.playerIndex].name}: ${round.darts.map((d) => d.multiplier == 1 ? 'S${d.zone == 25 ? 'B' : d.zone}' : (d.multiplier == 2 ? 'D${d.zone == 25 ? 'B' : d.zone}' : 'T${d.zone == 25 ? 'B' : d.zone}')).join(' - ')}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go(AppRoutes.play);
              },
              child: const Text('Revenir au menu'),
            ),
          ],
        );
      },
    );
  }
}

class _CricketScoreboard extends StatelessWidget {
  const _CricketScoreboard({required this.state});

  final CricketMatchState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          _PlayerPanel(
            player: state.players[0],
            isActive: state.currentPlayerIndex == 0 && state.status == MatchStatus.inProgress,
          ),
          const SizedBox(width: 10),
          _PlayerPanel(
            player: state.players[1],
            isActive: state.currentPlayerIndex == 1 && state.status == MatchStatus.inProgress,
          ),
        ],
      ),
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({required this.player, required this.isActive});

  final CricketPlayerState player;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.14) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.surfaceLight,
            width: isActive ? 1.4 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${player.score}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Legs ${player.legsWon} • Sets ${player.setsWon}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurnIndicator extends StatelessWidget {
  const _TurnIndicator({required this.state});

  final CricketMatchState state;

  @override
  Widget build(BuildContext context) {
    final dartIndex = (state.currentDartInTurn + 1).clamp(1, 3);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tour ${state.currentRound}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Flechette $dartIndex/3',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CricketGrid extends StatelessWidget {
  const _CricketGrid({
    required this.state,
    required this.onTapZone,
  });

  final CricketMatchState state;
  final ValueChanged<int> onTapZone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _GridHeader(),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: cricketZones.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final zone = cricketZones[index];
              return Row(
                children: [
                  Expanded(
                    child: _CricketCell(
                      hits: state.players[0].hits[zone] ?? 0,
                      active: state.currentPlayerIndex == 0 && state.status == MatchStatus.inProgress,
                      scoringOpen: state.players[0].isClosed(zone) && !state.players[1].isClosed(zone),
                      fullyClosed: state.players[0].isClosed(zone) && state.players[1].isClosed(zone),
                      onTap: () => onTapZone(zone),
                    ),
                  ),
                  Container(
                    width: 74,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      zone == 25 ? 'BULL' : '$zone',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _CricketCell(
                      hits: state.players[1].hits[zone] ?? 0,
                      active: state.currentPlayerIndex == 1 && state.status == MatchStatus.inProgress,
                      scoringOpen: state.players[1].isClosed(zone) && !state.players[0].isClosed(zone),
                      fullyClosed: state.players[1].isClosed(zone) && state.players[0].isClosed(zone),
                      onTap: () => onTapZone(zone),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GridHeader extends StatelessWidget {
  const _GridHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: Text(
            'Joueur 1',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          width: 74,
          child: Text(
            'Zone',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Text(
            'Joueur 2',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _CricketCell extends StatelessWidget {
  const _CricketCell({
    required this.hits,
    required this.active,
    required this.scoringOpen,
    required this.fullyClosed,
    required this.onTap,
  });

  final int hits;
  final bool active;
  final bool scoringOpen;
  final bool fullyClosed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cellColor = fullyClosed
        ? AppColors.surface
        : scoringOpen
            ? AppColors.primary.withValues(alpha: 0.12)
            : (active ? AppColors.card : AppColors.surface);

    final paintColor = fullyClosed ? AppColors.textHint : AppColors.textPrimary;

    return GestureDetector(
      onTap: active ? onTap : null,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.primary.withValues(alpha: 0.6) : AppColors.surfaceLight,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 34,
            height: 34,
            child: CustomPaint(
              painter: _CricketHitsPainter(hits: hits, color: paintColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _CricketHitsPainter extends CustomPainter {
  const _CricketHitsPainter({required this.hits, required this.color});

  final int hits;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final markSize = size.shortestSide * 0.28;

    if (hits >= 1) {
      canvas.drawLine(
        Offset(cx - markSize, cy + markSize),
        Offset(cx + markSize, cy - markSize),
        paint,
      );
    }
    if (hits >= 2) {
      canvas.drawLine(
        Offset(cx - markSize, cy - markSize),
        Offset(cx + markSize, cy + markSize),
        paint,
      );
    }
    if (hits >= 3) {
      canvas.drawCircle(Offset(cx, cy), markSize * 1.35, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CricketHitsPainter oldDelegate) {
    return oldDelegate.hits != hits || oldDelegate.color != color;
  }
}
