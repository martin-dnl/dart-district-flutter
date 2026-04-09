import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/config/translation_service.dart';
import '../../../core/network/api_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/match_history_list.dart';
import '../../../shared/widgets/player_avatar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../auth/controller/auth_controller.dart';
import '../../match/controller/ongoing_matches_controller.dart';
import '../../auth/models/user_model.dart';
import '../controller/profile_controller.dart';
import '../data/profile_service.dart';
import '../widgets/elo_chart.dart';
import '../widgets/badge_grid.dart';
import '../widgets/precision_section.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  UserModel? _visitorUser;
  bool _isLoadingVisitor = false;
  bool _isMutatingVisitorAction = false;
  bool _isFriend = false;
  bool _isBlocked = false;
  bool _hasPendingRequest = false;

  bool _isOwnProfile(UserModel? currentUser) {
    return widget.userId == null || widget.userId == currentUser?.id;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadVisitorProfileIfNeeded();
      await _refreshProfileData();
    });
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadVisitorProfileIfNeeded();
    }
  }

  Future<void> _loadVisitorProfileIfNeeded() async {
    final currentUser = ref.read(currentUserProvider);
    if (_isOwnProfile(currentUser) || widget.userId == null) {
      if (mounted) {
        setState(() {
          _visitorUser = null;
          _isLoadingVisitor = false;
          _isFriend = false;
          _isBlocked = false;
          _hasPendingRequest = false;
        });
      }
      return;
    }

    setState(() => _isLoadingVisitor = true);
    try {
      final service = ProfileService(ref.read(apiClientProvider));
      final userFuture = service.fetchUserById(widget.userId!);
      final statusFuture = service.getFriendshipStatus(widget.userId!);
      final results = await Future.wait([userFuture, statusFuture]);
      final user = results[0] as UserModel;
      final status = results[1] as Map<String, bool>;

      if (!mounted) return;
      setState(() {
        _visitorUser = user;
        _isFriend = status['is_friend'] ?? false;
        _isBlocked = status['is_blocked'] ?? false;
        _hasPendingRequest = status['has_pending_request'] ?? false;
        _isLoadingVisitor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingVisitor = false);
    }
  }

  Future<void> _refreshProfileData() async {
    final currentUser = ref.read(currentUserProvider);
    if (_isOwnProfile(currentUser)) {
      await Future.wait([
        ref.read(authControllerProvider.notifier).refreshCurrentUser(),
        ref.read(profileControllerProvider.notifier).refresh(),
        ref.read(ongoingMatchesControllerProvider.notifier).refresh(),
      ]);
      return;
    }
    await _loadVisitorProfileIfNeeded();
  }

  Future<void> _changeAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(
                t('SCREEN.PROFILE.TAKE_PHOTO', fallback: 'Prendre une photo'),
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                t(
                  'SCREEN.PROFILE.CHOOSE_GALLERY',
                  fallback: 'Choisir dans la galerie',
                ),
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) {
      return;
    }

    XFile? picked;
    try {
      picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 88,
      );
    } on PlatformException catch (error) {
      // Some Android devices report picker cancel as an exception.
      final code = error.code.toLowerCase();
      final message = (error.message ?? '').toLowerCase();
      if (code.contains('cancel') || message.contains('cancel')) {
        return;
      }
      rethrow;
    }

    if (picked == null || !mounted) {
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      final service = ProfileService(api);
      await service.uploadAvatar(File(picked.path));
      await ref.read(authControllerProvider.notifier).refreshCurrentUser();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'SCREEN.PROFILE.PHOTO_UPDATED',
              fallback: 'Photo de profil mise a jour',
            ),
          ),
        ),
      );
    } catch (error) {
      var message = t(
        'SCREEN.PROFILE.PHOTO_UPDATE_FAILED',
        fallback: 'Impossible de mettre a jour la photo',
      );
      if (error is DioException) {
        final data = error.response?.data;
        if (data is Map<String, dynamic>) {
          final backendMessage = data['message'];
          if (backendMessage is String && backendMessage.trim().isNotEmpty) {
            message = backendMessage;
          }
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _handleVisitorFriendAction(UserModel visitorUser) async {
    if (_isMutatingVisitorAction) return;

    final service = ProfileService(ref.read(apiClientProvider));
    setState(() => _isMutatingVisitorAction = true);
    try {
      if (_isFriend) {
        final confirmed = await showConfirmDialog(
          context: context,
          title: t('SCREEN.PROFILE.REMOVE_FRIEND', fallback: 'Retirer cet ami ?'),
          message: t(
            'SCREEN.PROFILE.REMOVE_FRIEND_CONFIRM',
            fallback: 'Cette personne sera retiree de votre liste d\'amis.',
          ),
          confirmLabel: t('SCREEN.PROFILE.REMOVE', fallback: 'Retirer'),
          confirmColor: AppColors.error,
        );
        if (!confirmed) return;
        await service.removeFriend(visitorUser.id);
        setState(() {
          _isFriend = false;
          _hasPendingRequest = false;
        });
      } else {
        final confirmed = await showConfirmDialog(
          context: context,
          title:
              '${t('SCREEN.PROFILE.ADD', fallback: 'Ajouter')} ${visitorUser.username} ?',
          message: t(
            'SCREEN.PROFILE.ADD_FRIEND_CONFIRM',
            fallback: 'Une demande d\'ami sera envoyee.',
          ),
          confirmLabel: t('SCREEN.PROFILE.SEND', fallback: 'Envoyer'),
        );
        if (!confirmed) return;
        await service.sendFriendRequest(visitorUser.id);
        setState(() => _hasPendingRequest = true);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'SCREEN.PROFILE.ACTION_UNAVAILABLE',
              fallback: 'Action indisponible pour le moment.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutatingVisitorAction = false);
      }
    }
  }

  Future<void> _handleVisitorBlock(UserModel visitorUser) async {
    if (_isMutatingVisitorAction) return;

    final confirmed = await showConfirmDialog(
      context: context,
      title:
          '${t('SCREEN.PROFILE.BLOCK', fallback: 'Bloquer')} ${visitorUser.username} ?',
      message: t(
        'SCREEN.PROFILE.BLOCK_CONFIRM',
        fallback: 'Cet utilisateur ne pourra plus vous contacter.',
      ),
      confirmLabel: t('SCREEN.PROFILE.BLOCK', fallback: 'Bloquer'),
      confirmColor: AppColors.error,
    );
    if (!confirmed) return;

    setState(() => _isMutatingVisitorAction = true);
    try {
      final service = ProfileService(ref.read(apiClientProvider));
      await service.blockUser(visitorUser.id);
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'SCREEN.PROFILE.BLOCK_FAILED',
              fallback: 'Blocage impossible pour le moment.',
            ),
          ),
        ),
      );
      setState(() => _isMutatingVisitorAction = false);
    }
  }

  void _showMyQrCode() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user.username,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: user.id,
              version: QrVersions.auto,
              size: 200,
              eyeStyle: const QrEyeStyle(color: AppColors.textPrimary),
              dataModuleStyle: const QrDataModuleStyle(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t(
                'SCREEN.PROFILE.QR_HINT',
                fallback: 'Faites scanner ce code pour etre ajoute ou defie',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = _isOwnProfile(currentUser);
    final user = isOwnProfile ? currentUser : _visitorUser;
    final profileState = ref.watch(profileControllerProvider);
    final recentMatches = profileState.matchHistory.take(5).toList();
    final wins = user?.stats.matchesWon ?? 0;
    final losses = (user?.stats.matchesPlayed ?? 0) - wins;

    if (!isOwnProfile && _isLoadingVisitor) {
      return AppScaffold(
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!isOwnProfile && user == null) {
      return AppScaffold(
        child: Center(
          child: Text(
            t('SCREEN.PROFILE.NOT_FOUND', fallback: 'Profil introuvable'),
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return AppScaffold(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshProfileData,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Profile header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            if (isOwnProfile &&
                                !(currentUser?.isGuest ?? false))
                              IconButton(
                                onPressed: _showMyQrCode,
                                icon: const Icon(
                                  Icons.qr_code_2,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            else
                              const SizedBox(width: 48),
                            const Spacer(),
                            if (isOwnProfile)
                              IconButton(
                                onPressed: () =>
                                    context.push(AppRoutes.settings),
                                icon: const Icon(
                                  Icons.settings_outlined,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            else ...[
                              if (!_isFriend)
                                IconButton(
                                  onPressed:
                                      _isBlocked || _isMutatingVisitorAction
                                      ? null
                                      : () => _handleVisitorBlock(user!),
                                  icon: const Icon(
                                    Icons.block,
                                    color: AppColors.error,
                                  ),
                                  tooltip: t('SCREEN.PROFILE.BLOCK', fallback: 'Bloquer'),
                                ),
                              IconButton(
                                onPressed:
                                    _isBlocked || _isMutatingVisitorAction
                                    ? null
                                    : () => _handleVisitorFriendAction(user!),
                                icon: Icon(
                                  _isFriend
                                      ? Icons.person_remove
                                      : Icons.person_add,
                                  color: _isFriend
                                      ? AppColors.error
                                      : AppColors.primary,
                                ),
                                tooltip: _isFriend
                                    ? t(
                                        'SCREEN.PROFILE.REMOVE_FRIEND_SHORT',
                                        fallback: 'Retirer ami',
                                      )
                                    : (_hasPendingRequest
                                          ? t(
                                              'SCREEN.PROFILE.REQUEST_SENT',
                                              fallback: 'Demande envoyee',
                                            )
                                          : t(
                                              'SCREEN.PROFILE.ADD_FRIEND',
                                              fallback: 'Ajouter ami',
                                            )),
                              ),
                            ],
                          ],
                        ),

                        GestureDetector(
                          onTap: isOwnProfile ? _changeAvatar : null,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              PlayerAvatar(
                                name: user?.username ?? 'Joueur',
                                imageUrl: user?.avatarUrl,
                                size: 90,
                                showBorder: true,
                              ),
                              if (isOwnProfile)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.surface,
                                      border: Border.all(
                                        color: AppColors.stroke,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.photo_camera,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Username
                        Text(
                          user?.username ?? 'Joueur',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isOwnProfile ? (user?.email ?? '') : '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (user?.clubName != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              user!.clubName!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Stats cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ProfileStatTile(
                            title: t('SCREEN.PROFILE.ELO', fallback: 'ELO'),
                            child: Text(
                              '${user?.elo ?? 1000}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _ProfileStatTile(
                            title: t('SCREEN.PROFILE.WIN_LOSS', fallback: 'V / D'),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                                children: [
                                  TextSpan(
                                    text: '$wins',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const TextSpan(text: 'V / '),
                                  TextSpan(
                                    text: '$losses',
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const TextSpan(text: 'D'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ProfileStatTile(
                            title: t('SCREEN.PROFILE.AVERAGE', fallback: 'Moyenne'),
                            child: Text(
                              user?.stats.averageScore.toStringAsFixed(1) ??
                                  '0',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ProfileStatTile(
                            title: t('SCREEN.PROFILE.CHECKOUT', fallback: 'Checkout'),
                            child: Text(
                              '${user?.stats.checkoutRate.toStringAsFixed(0) ?? 0}%',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _ProfileStatTile(
                            title: t('SCREEN.PROFILE.SHOTS', fallback: 'Tirs'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ShotLine(
                                  count: user?.stats.highest180s ?? 0,
                                  label: '180',
                                ),
                                const SizedBox(height: 2),
                                _ShotLine(
                                  count: user?.stats.count140Plus ?? 0,
                                  label: '140+',
                                ),
                                const SizedBox(height: 2),
                                _ShotLine(
                                  count: user?.stats.count100Plus ?? 0,
                                  label: '100+',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: PrecisionSection(
                    userId: isOwnProfile ? null : user?.id,
                  ),
                ),

                if (isOwnProfile)
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: t(
                        'SCREEN.PROFILE.ELO_PROGRESSION',
                        fallback: 'Progression ELO',
                      ),
                    ),
                  ),
                if (isOwnProfile)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: EloChart(
                        points: profileState.eloPoints,
                        mode: profileState.eloMode,
                        periodLabel: profileState.eloPeriodLabel,
                        offset: profileState.eloOffset,
                        isLoading: profileState.isEloLoading,
                        onModeChanged: (mode) => ref
                            .read(profileControllerProvider.notifier)
                            .setEloMode(mode),
                        onShiftOffset: (offset) => ref
                            .read(profileControllerProvider.notifier)
                            .shiftEloPeriod(offset - profileState.eloOffset),
                      ),
                    ),
                  ),

                if (isOwnProfile)
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: t(
                        'SCREEN.PROFILE.HISTORY',
                        fallback: 'Historique des matchs',
                      ),
                    ),
                  ),
                if (isOwnProfile)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: MatchHistoryList(
                        matches: recentMatches,
                        onMatchTap: (matchId) =>
                            context.push('/match/$matchId/report'),
                      ),
                    ),
                  ),
                if (isOwnProfile)
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: t('SCREEN.PROFILE.BADGES', fallback: 'Badges'),
                      actionText: t('SCREEN.HOME.VIEW_ALL', fallback: 'Voir tout'),
                      onAction: () => context.push(AppRoutes.badges),
                    ),
                  ),
                if (isOwnProfile)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: BadgeGrid(
                        badges: profileState.badges,
                        maxDisplay: 4,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileStatTile extends StatelessWidget {
  const _ProfileStatTile({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ShotLine extends StatelessWidget {
  const _ShotLine({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        children: [
          TextSpan(
            text: '$count',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(text: ' x $label'),
        ],
      ),
    );
  }
}
