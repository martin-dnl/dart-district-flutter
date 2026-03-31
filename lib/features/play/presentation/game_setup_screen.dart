import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../contacts/controller/contacts_controller.dart';
import '../../contacts/models/contact_models.dart';
import '../../match/controller/pending_invitation_controller.dart';
import '../../match/controller/match_controller.dart';
import '../../match/data/match_service.dart';
import '../../../shared/widgets/dart_button.dart';
import '../controller/play_controller.dart';
import '../../../core/network/api_providers.dart';
import '../../auth/controller/auth_controller.dart';

class GameSetupScreen extends ConsumerStatefulWidget {
  final String gameMode;

  const GameSetupScreen({super.key, required this.gameMode});

  @override
  ConsumerState<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends ConsumerState<GameSetupScreen> {
  FinishType _finishType = FinishType.doubleOut;
  int _legsPerSet = 3;
  int _setsToWin = 1;
  GameStartOption _startOption = GameStartOption.guest;

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Configuration · ${widget.gameMode}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mode banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.gps_fixed,
                      size: 40,
                      color: AppColors.background,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.gameMode,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.background,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Options de jeu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _OptionCard(
                      icon: Icons.person_add,
                      label: 'Inviter un ami',
                      selected: _startOption == GameStartOption.inviteFriend,
                      onTap: () async {
                        final result = await context.push(
                          AppRoutes.gameInvitePlayer,
                        );
                        if (!mounted) return;

                        if (result is ContactModel) {
                          setState(() {
                            _startOption = GameStartOption.inviteFriend;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OptionCard(
                      icon: Icons.qr_code_scanner,
                      label: 'Scanner QR',
                      selected: _startOption == GameStartOption.scanQr,
                      onTap: () {
                        setState(() {
                          _startOption = GameStartOption.scanQr;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Mode QR actif. Le scan pourra etre lance dans l\'etape suivante.',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OptionCard(
                      icon: Icons.person_outline,
                      label: 'Vs Invite',
                      selected: _startOption == GameStartOption.guest,
                      onTap: () {
                        setState(() {
                          _startOption = GameStartOption.guest;
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_startOption == GameStartOption.inviteFriend) ...[
                const SizedBox(height: 10),
                _SelectedFriendInfo(
                  friendName:
                      contacts.selectedFriend?.username ??
                      'Aucun joueur selectionne',
                ),
              ],
              const SizedBox(height: 24),

              // Finish type
              const Text(
                'Type de finish',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: FinishType.values.map((type) {
                  final selected = _finishType == type;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _finishType = type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: selected
                                ? null
                                : Border.all(
                                    color: AppColors.surfaceLight,
                                    width: 0.5,
                                  ),
                          ),
                          child: Text(
                            _finishLabel(type),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? AppColors.background
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Legs per set
              _buildCounter(
                label: 'Legs par set',
                value: _legsPerSet,
                onMinus: () {
                  if (_legsPerSet > 1) setState(() => _legsPerSet--);
                },
                onPlus: () => setState(() => _legsPerSet++),
              ),
              const SizedBox(height: 16),

              // Sets to win
              _buildCounter(
                label: 'Sets pour gagner',
                value: _setsToWin,
                onMinus: () {
                  if (_setsToWin > 1) setState(() => _setsToWin--);
                },
                onPlus: () => setState(() => _setsToWin++),
              ),

              const Spacer(),

              // Start button
              DartButton(
                text: 'Commencer la partie',
                icon: Icons.play_arrow_rounded,
                width: double.infinity,
                onPressed: () async {
                  final notifier = ref.read(playControllerProvider.notifier);
                  final contactsState = ref.read(contactsControllerProvider);
                  final authState = ref.read(authControllerProvider);

                  final gameMode = _resolveGameMode(widget.gameMode);
                  final startingScore = _resolveStartingScore(gameMode);
                  final opponentName = switch (_startOption) {
                    GameStartOption.guest => 'Invite',
                    GameStartOption.scanQr => 'Adversaire QR',
                    GameStartOption.inviteFriend =>
                      contactsState.selectedFriend?.username ?? 'Ami',
                  };

                  if (_startOption == GameStartOption.inviteFriend &&
                      contactsState.selectedFriend == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Selectionnez un ami dans Contacts avant de demarrer.',
                        ),
                      ),
                    );
                    return;
                  }

                  notifier.setMode(gameMode);
                  notifier.setFinishType(_finishType);
                  notifier.setLegsPerSet(_legsPerSet);
                  notifier.setSetsToWin(_setsToWin);

                  if (_startOption == GameStartOption.inviteFriend) {
                    final selectedFriend = contactsState.selectedFriend;
                    final currentUser = authState.user;

                    if (selectedFriend == null || currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Invitation impossible pour le moment.',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      final api = ref.read(apiClientProvider);
                      final service = MatchService(api);

                      final invitation = await service.createMatchInvitation(
                        inviteeId: selectedFriend.id,
                        mode: _modeLabel(gameMode),
                        startingScore: startingScore,
                        playerNames: [
                          currentUser.username,
                          selectedFriend.username,
                        ],
                        setsToWin: _setsToWin,
                        legsPerSet: _legsPerSet,
                        finishType: _finishApiLabel(_finishType),
                      );

                      ref
                          .read(pendingInvitationProvider.notifier)
                          .startWaiting(invitation);

                      if (context.mounted) {
                        context.pop();
                      }
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Impossible d\'envoyer l\'invitation.'),
                        ),
                      );
                    }
                    return;
                  }

                  ref
                      .read(matchControllerProvider.notifier)
                      .setupMatch(
                        mode: _modeLabel(gameMode),
                        startingScore: startingScore,
                        setsToWin: _setsToWin,
                        legsPerSet: _legsPerSet,
                        finishType: _finishApiLabel(_finishType),
                        playerNames: ['Joueur 1', opponentName],
                      );

                  context.push(AppRoutes.matchLive);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCounter({
    required String label,
    required int value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            children: [
              _CounterButton(icon: Icons.remove, onTap: onMinus),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _CounterButton(icon: Icons.add, onTap: onPlus),
            ],
          ),
        ],
      ),
    );
  }

  String _finishLabel(FinishType type) {
    switch (type) {
      case FinishType.doubleOut:
        return 'Double Out';
      case FinishType.singleOut:
        return 'Single Out';
      case FinishType.masterOut:
        return 'Master Out';
    }
  }

  GameMode _resolveGameMode(String value) {
    switch (value.toLowerCase()) {
      case '301':
        return GameMode.x01_301;
      case '501':
        return GameMode.x01_501;
      case '701':
        return GameMode.x01_701;
      case 'cricket':
        return GameMode.cricket;
      case 'chasseur':
        return GameMode.chasseur;
      default:
        return GameMode.x01_501;
    }
  }

  int _resolveStartingScore(GameMode mode) {
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

  String _modeLabel(GameMode mode) {
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

  String _finishApiLabel(FinishType type) {
    switch (type) {
      case FinishType.doubleOut:
        return 'double_out';
      case FinishType.singleOut:
        return 'single_out';
      case FinishType.masterOut:
        return 'master_out';
    }
  }
}

enum GameStartOption { inviteFriend, scanQr, guest }

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.surfaceLight,
            width: selected ? 1.2 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedFriendInfo extends StatelessWidget {
  const _SelectedFriendInfo({required this.friendName});

  final String friendName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight, width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_pin_circle_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Joueur ajoute: $friendName',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 18),
      ),
    );
  }
}
