import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../club/models/club_model.dart';
import '../../contacts/controller/contacts_controller.dart';
import '../../contacts/models/contact_models.dart';
import '../../match/controller/chasseur_match_controller.dart';
import '../../match/controller/cricket_match_controller.dart';
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
  bool _isRanked = false;
  bool _isTerritorial = false;
  GameStartOption _startOption = GameStartOption.guest;
  ContactModel? _selectedOpponent;
  ClubModel? _territoryClub;
  bool _isLaunchingScan = false;
  final List<TextEditingController> _localGuestControllers =
      <TextEditingController>[TextEditingController()];

  bool get _isSpecialMode =>
      widget.gameMode.toLowerCase() == 'cricket' ||
      widget.gameMode.toLowerCase() == 'chasseur';

  bool get _isCricketMode => widget.gameMode.toLowerCase() == 'cricket';
  bool get _isChasseurMode => widget.gameMode.toLowerCase() == 'chasseur';

  List<String> _localGuestNames() {
    return _localGuestControllers
        .map((controller) => controller.text.trim())
        .where((name) => name.isNotEmpty)
        .take(3)
        .toList(growable: false);
  }

  @override
  void dispose() {
    for (final controller in _localGuestControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final isGuest = authState.user?.isGuest ?? false;
    final currentUserName = authState.user?.username ?? 'Moi';

    if (isGuest && _startOption != GameStartOption.guest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _startOption = GameStartOption.guest;
          _selectedOpponent = null;
          _isRanked = false;
          _isTerritorial = false;
          _territoryClub = null;
        });
      });
    }
    final selectedOpponent =
        _selectedOpponent ??
        (_startOption == GameStartOption.inviteFriend
            ? contacts.selectedFriend
            : null);

    if (_isSpecialMode &&
        (_isRanked || _isTerritorial || _territoryClub != null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isRanked = false;
          _isTerritorial = false;
          _territoryClub = null;
        });
      });
    }

    final canStart = _canStartMatch(selectedOpponent);
    final opponentLabel = selectedOpponent?.username ?? 'Adversaire';
    final localNames = _localGuestNames();
    final startingPlayers = _startOption == GameStartOption.guest
        ? <String>[currentUserName, ...localNames]
        : <String>[currentUserName, opponentLabel];
    if (_startingPlayerIndex >= startingPlayers.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() => _startingPlayerIndex = 0);
      });
    }

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
                Row(
                  children: [
                    if (!isGuest) ...[
                      Expanded(
                        child: _OptionCard(
                          icon: Icons.person_add,
                          label: 'Inviter',
                          selected:
                              _startOption == GameStartOption.inviteFriend,
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
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _OptionCard(
                          icon: Icons.qr_code_scanner,
                          label: 'Scan',
                          selected: _startOption == GameStartOption.scanQr,
                          onTap: _handleUserQrScan,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: _OptionCard(
                        icon: Icons.person_outline,
                        label: 'Local',
                        selected: _startOption == GameStartOption.guest,
                        onTap: () {
                          setState(() {
                            _startOption = GameStartOption.guest;
                            _selectedOpponent = null;
                            _isRanked = false;
                            _isTerritorial = false;
                            _territoryClub = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (selectedOpponent != null) ...[
                  const SizedBox(height: 10),
                  _SelectedFriendInfo(friendName: selectedOpponent.username),
                ],
                if (_startOption == GameStartOption.guest) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Joueurs locaux invites',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List<Widget>.generate(_localGuestControllers.length, (
                    index,
                  ) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _localGuestControllers[index],
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Invite ${index + 1}',
                                filled: true,
                                fillColor: AppColors.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.stroke,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_localGuestControllers.length > 1)
                            IconButton(
                              onPressed: () {
                                final removed = _localGuestControllers.removeAt(
                                  index,
                                );
                                removed.dispose();
                                setState(() {
                                  _startingPlayerIndex = 0;
                                });
                              },
                              icon: const Icon(
                                Icons.close,
                                color: AppColors.error,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  if (_localGuestControllers.length < 3)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _localGuestControllers.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un joueur'),
                    ),
                ],
                if (!isGuest && !_isSpecialMode) ...[
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isRanked ? 'Classe' : 'Amical',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Switch.adaptive(
                          value: _isRanked,
                          activeThumbColor: AppColors.primary,
                          onChanged:
                              _startOption == GameStartOption.guest ||
                                  _isTerritorial
                              ? null
                              : (val) {
                                  setState(() {
                                    _isRanked = val;
                                  });
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Territorial',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Switch.adaptive(
                              value: _isTerritorial,
                              activeThumbColor: AppColors.primary,
                              onChanged: _startOption == GameStartOption.guest
                                  ? null
                                  : (val) {
                                      if (!val) {
                                        setState(() {
                                          _isTerritorial = false;
                                          _territoryClub = null;
                                        });
                                        return;
                                      }

                                      setState(() {
                                        _isTerritorial = true;
                                        _isRanked = true;
                                      });
                                      _handleTerritoryClubScan();
                                    },
                            ),
                          ],
                        ),
                        if (_isTerritorial && _territoryClub != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _territoryClub!.name,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (!_isSpecialMode) ...[
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
                ],
                if (!_isChasseurMode) ...[
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
                  const SizedBox(height: 6),
                  Text(
                    'Format: premier a $_setsToWin set(s) (FT$_setsToWin)',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
                    segments: List<ButtonSegment<int>>.generate(
                      startingPlayers.length,
                      (index) => ButtonSegment<int>(
                        value: index,
                        label: Text(startingPlayers[index]),
                      ),
                    ),
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
        return _localGuestNames().isNotEmpty;
      case GameStartOption.inviteFriend:
      case GameStartOption.scanQr:
        return selectedOpponent != null &&
            (!_isTerritorial || _territoryClub != null);
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

  Future<void> _handleTerritoryClubScan() async {
    if (_isLaunchingScan) {
      return;
    }

    setState(() {
      _isLaunchingScan = true;
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
        _isTerritorial = false;
        _territoryClub = null;
      });
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLaunchingScan = false;
      _territoryClub = result;
    });
  }

  void _showTerritoryError(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Defi territorial impossible',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            message,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startMatch({required ContactModel? selectedOpponent}) async {
    final notifier = ref.read(playControllerProvider.notifier);
    final authState = ref.read(authControllerProvider);

    final gameMode = _resolveGameMode(widget.gameMode);
    final startingScore = _resolveStartingScore(gameMode);

    notifier.setMode(gameMode);
    notifier.setFinishType(_isSpecialMode ? FinishType.singleOut : _finishType);
    notifier.setLegsPerSet(_legsPerSet);
    notifier.setSetsToWin(_setsToWin);

    final currentUserName = authState.user?.username ?? 'Joueur 1';
    final localNames = _localGuestNames();
    final localPlayers = <String>[currentUserName, ...localNames];

    if (_startOption == GameStartOption.guest) {
      if (_isCricketMode) {
        ref
            .read(cricketMatchControllerProvider.notifier)
            .setupMatch(
              playerNames: localPlayers,
              setsToWin: _setsToWin,
              legsPerSet: _legsPerSet,
              startingPlayerIndex: _startingPlayerIndex,
            );
        if (mounted) {
          context.push(AppRoutes.matchCricket);
        }
        return;
      }

      if (_isChasseurMode) {
        ref
            .read(chasseurMatchControllerProvider.notifier)
            .setupMatch(
              playerNames: localPlayers,
              startingPlayerIndex: _startingPlayerIndex,
            );
        if (mounted) {
          context.push(AppRoutes.matchChasseurZones);
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
            startingPlayerIndex: _startingPlayerIndex,
            isRanked: false,
            playerNames: localPlayers,
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

    if (_isTerritorial) {
      if (_territoryClub == null) {
        _showTerritoryError(
          'Scannez le QR du club du territoire avant de lancer la partie.',
        );
        return;
      }

      if (currentUser.clubId != null &&
          currentUser.clubId == selectedOpponent.clubId) {
        _showTerritoryError('Les deux joueurs appartiennent au meme club.');
        return;
      }

      final territoryClubId = _territoryClub!.id;
      final currentUserInClub = currentUser.clubId == territoryClubId;
      final opponentInClub = selectedOpponent.clubId == territoryClubId;

      if (!currentUserInClub && !opponentInClub) {
        _showTerritoryError(
          'Aucun des deux joueurs n\'appartient au club ${_territoryClub!.name}.',
        );
        return;
      }
    }

    try {
      final api = ref.read(apiClientProvider);
      final service = MatchService(api);
      final invitationStartingScore = _isSpecialMode ? 99999 : startingScore;

      final invitation = await service.createMatchInvitation(
        inviteeId: selectedOpponent.id,
        mode: _modeLabel(gameMode),
        startingScore: invitationStartingScore,
        playerNames: [currentUser.username, selectedOpponent.username],
        setsToWin: _setsToWin,
        legsPerSet: _legsPerSet,
        finishType: _finishApiLabel(_finishType),
        isRanked: _isRanked,
        isTerritorial: _isTerritorial,
        territoryClubId: _isTerritorial ? _territoryClub?.id : null,
        territoryCodeIris: _isTerritorial ? _territoryClub?.codeIris : null,
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
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
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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
