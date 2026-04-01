import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../club/models/club_model.dart';
import '../../club/widgets/member_list_tile.dart';
import '../../contacts/controller/contacts_controller.dart';
import '../../contacts/models/contact_models.dart';
import '../../match/controller/pending_invitation_controller.dart';
import '../../match/controller/match_controller.dart';
import '../../match/data/match_service.dart';
import '../../../shared/widgets/dart_button.dart';
import '../controller/play_controller.dart';
import 'qr_scan_screen.dart';
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
  int _startingPlayerIndex = 0;
  bool _isRanked = true;
  GameStartOption _startOption = GameStartOption.guest;
  ContactModel? _selectedOpponent;
  bool _isLaunchingScan = false;

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final currentUserName = authState.user?.username ?? 'Moi';
    final selectedOpponent =
        _selectedOpponent ??
        (_startOption == GameStartOption.inviteFriend
            ? contacts.selectedFriend
            : null);
    final canStart = _canStartMatch(selectedOpponent);
    final opponentLabel = selectedOpponent?.username ?? 'Adversaire';

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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.15,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _OptionCard(
                      icon: Icons.person_add,
                      label: 'Inviter un ami',
                      selected: _startOption == GameStartOption.inviteFriend,
                      onTap: () async {
                        final result = await context.push(
                          AppRoutes.gameInvitePlayer,
                        );
                        if (!mounted) {
                          return;
                        }
                        final selected = result is ContactModel
                            ? result
                            : ref
                                  .read(contactsControllerProvider)
                                  .selectedFriend;
                        if (selected == null) {
                          return;
                        }
                        setState(() {
                          _startOption = GameStartOption.inviteFriend;
                          _selectedOpponent = selected;
                        });
                      },
                    ),
                    _OptionCard(
                      icon: Icons.qr_code_scanner,
                      label: 'Scanner QR',
                      selected: _startOption == GameStartOption.scanQr,
                      onTap: _handleUserQrScan,
                    ),
                    _OptionCard(
                      icon: Icons.flag_circle,
                      label: 'Territoire',
                      selected: _startOption == GameStartOption.territory,
                      onTap: _handleTerritoryScan,
                    ),
                    _OptionCard(
                      icon: Icons.person_outline,
                      label: 'Vs Invite',
                      selected: _startOption == GameStartOption.guest,
                      onTap: () {
                        setState(() {
                          _startOption = GameStartOption.guest;
                          _selectedOpponent = null;
                          _isRanked = false;
                        });
                      },
                    ),
                  ],
                ),
                if (selectedOpponent != null) ...[
                  const SizedBox(height: 10),
                  _SelectedFriendInfo(friendName: selectedOpponent.username),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Type de match',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(value: true, label: Text('Classe')),
                      ButtonSegment<bool>(value: false, label: Text('Amical')),
                    ],
                    selected: {_isRanked},
                    onSelectionChanged: _startOption == GameStartOption.guest
                        ? null
                        : (values) {
                            setState(() {
                              _isRanked = values.first;
                            });
                          },
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      minimumSize: const WidgetStatePropertyAll(
                        Size(double.infinity, 48),
                      ),
                      side: const WidgetStatePropertyAll(
                        BorderSide(color: AppColors.stroke),
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.background;
                        }
                        return AppColors.textSecondary;
                      }),
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.primary;
                        }
                        return AppColors.surface;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
                _buildCounter(
                  label: 'Legs par set (BO)',
                  value: _legsPerSet,
                  onMinus: () {
                    if (_legsPerSet > 1) {
                      setState(() => _legsPerSet--);
                    }
                  },
                  onPlus: () => setState(() => _legsPerSet++),
                ),
                const SizedBox(height: 16),
                _buildCounter(
                  label: 'Sets pour gagner',
                  value: _setsToWin,
                  onMinus: () {
                    if (_setsToWin > 1) {
                      setState(() => _setsToWin--);
                    }
                  },
                  onPlus: () => setState(() => _setsToWin++),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Qui commence ?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment<int>(
                        value: 0,
                        label: Text(currentUserName),
                      ),
                      ButtonSegment<int>(value: 1, label: Text(opponentLabel)),
                    ],
                    selected: {_startingPlayerIndex},
                    onSelectionChanged: (values) {
                      setState(() {
                        _startingPlayerIndex = values.first;
                      });
                    },
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      minimumSize: const WidgetStatePropertyAll(
                        Size(double.infinity, 48),
                      ),
                      side: const WidgetStatePropertyAll(
                        BorderSide(color: AppColors.stroke),
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.background;
                        }
                        return AppColors.textSecondary;
                      }),
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.primary;
                        }
                        return AppColors.surface;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                DartButton(
                  text: 'Commencer la partie',
                  icon: Icons.play_arrow_rounded,
                  width: double.infinity,
                  onPressed: canStart
                      ? () => _startMatch(selectedOpponent: selectedOpponent)
                      : null,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _canStartMatch(ContactModel? selectedOpponent) {
    switch (_startOption) {
      case GameStartOption.guest:
        return true;
      case GameStartOption.inviteFriend:
      case GameStartOption.scanQr:
      case GameStartOption.territory:
        return selectedOpponent != null;
    }
  }

  Future<void> _handleUserQrScan() async {
    if (_isLaunchingScan) {
      return;
    }
    setState(() {
      _isLaunchingScan = true;
      _startOption = GameStartOption.scanQr;
    });
    final result = await context.push(
      AppRoutes.qrScan,
      extra: {'mode': QrScanMode.user.name},
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _isLaunchingScan = false;
      if (result is ContactModel) {
        _selectedOpponent = result;
      }
    });
  }

  Future<void> _handleTerritoryScan() async {
    if (_isLaunchingScan) {
      return;
    }

    setState(() {
      _isLaunchingScan = true;
      _startOption = GameStartOption.territory;
    });

    final result = await context.push(
      AppRoutes.qrScan,
      extra: {'mode': QrScanMode.club.name},
    );

    if (!mounted) {
      return;
    }

    if (result is! ClubModel) {
      setState(() {
        _isLaunchingScan = false;
      });
      return;
    }

    final selected = await showModalBottomSheet<ContactModel>(
      context: context,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (context) {
        if (result.members.isEmpty) {
          return const SizedBox(
            height: 180,
            child: Center(
              child: Text(
                'Aucun membre disponible dans ce club.',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selectionnez un adversaire (${result.name})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: result.members.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final member = result.members[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          context.pop(
                            ContactModel(
                              id: member.id,
                              username: member.username,
                              avatarUrl: member.avatarUrl,
                              elo: member.elo,
                            ),
                          );
                        },
                        child: MemberListTile(member: member, rank: index + 1),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLaunchingScan = false;
      if (selected != null) {
        _selectedOpponent = selected;
      }
    });
  }

  Future<void> _startMatch({required ContactModel? selectedOpponent}) async {
    final notifier = ref.read(playControllerProvider.notifier);
    final authState = ref.read(authControllerProvider);

    final gameMode = _resolveGameMode(widget.gameMode);
    final startingScore = _resolveStartingScore(gameMode);

    notifier.setMode(gameMode);
    notifier.setFinishType(_finishType);
    notifier.setLegsPerSet(_legsPerSet);
    notifier.setSetsToWin(_setsToWin);

    if (_startOption == GameStartOption.guest) {
      final currentUserName = authState.user?.username ?? 'Joueur 1';
      ref
          .read(matchControllerProvider.notifier)
          .setupMatch(
            mode: _modeLabel(gameMode),
            startingScore: startingScore,
            setsToWin: _setsToWin,
            legsPerSet: _legsPerSet,
            finishType: _finishApiLabel(_finishType),
            startingPlayerIndex: _startingPlayerIndex,
            isRanked: false,
            playerNames: [currentUserName, 'Invite'],
          );

      if (mounted) {
        context.push(AppRoutes.matchLive);
      }
      return;
    }

    final currentUser = authState.user;
    if (currentUser == null || selectedOpponent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selectionnez un adversaire avant de demarrer.'),
        ),
      );
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      final service = MatchService(api);

      final invitation = await service.createMatchInvitation(
        inviteeId: selectedOpponent.id,
        mode: _modeLabel(gameMode),
        startingScore: startingScore,
        playerNames: [currentUser.username, selectedOpponent.username],
        setsToWin: _setsToWin,
        legsPerSet: _legsPerSet,
        finishType: _finishApiLabel(_finishType),
        isRanked: _isRanked,
        isTerritorial: _startOption == GameStartOption.territory,
      );

      ref.read(pendingInvitationProvider.notifier).startWaiting(invitation);

      if (mounted) {
        context.pop();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'envoyer l\'invitation.')),
      );
    }
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

enum GameStartOption { inviteFriend, scanQr, territory, guest }

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
