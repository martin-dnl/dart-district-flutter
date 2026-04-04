import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/network/api_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/match_history_list.dart';
import '../../../shared/widgets/player_avatar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../auth/controller/auth_controller.dart';
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadVisitorProfileIfNeeded(),
    );
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

  Future<void> _changeAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) {
      return;
    }

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 88,
    );

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
        const SnackBar(content: Text('Photo de profil mise a jour')),
      );
    } catch (error) {
      var message = 'Impossible de mettre a jour la photo';
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
          title: 'Retirer cet ami ?',
          message: 'Cette personne sera retiree de votre liste d\'amis.',
          confirmLabel: 'Retirer',
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
          title: 'Ajouter ${visitorUser.username} ?',
          message: 'Une demande d\'ami sera envoyee.',
          confirmLabel: 'Envoyer',
        );
        if (!confirmed) return;
        await service.sendFriendRequest(visitorUser.id);
        setState(() => _hasPendingRequest = true);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action indisponible pour le moment.')),
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
      title: 'Bloquer ${visitorUser.username} ?',
      message: 'Cet utilisateur ne pourra plus vous contacter.',
      confirmLabel: 'Bloquer',
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
        const SnackBar(content: Text('Blocage impossible pour le moment.')),
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
            const Text(
              'Faites scanner ce code pour etre ajoute ou defie',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
    final losses =
        (user?.stats.matchesPlayed ?? 0) - (user?.stats.matchesWon ?? 0);

    if (!isOwnProfile && _isLoadingVisitor) {
      return AppScaffold(
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!isOwnProfile && user == null) {
      return AppScaffold(
        child: const Center(
          child: Text(
            'Profil introuvable',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return AppScaffold(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Profile header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (isOwnProfile && !(currentUser?.isGuest ?? false))
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
                              onPressed: () => context.push(AppRoutes.settings),
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
                                tooltip: 'Bloquer',
                              ),
                            IconButton(
                              onPressed: _isBlocked || _isMutatingVisitorAction
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
                                  ? 'Retirer ami'
                                  : (_hasPendingRequest
                                        ? 'Demande envoyee'
                                        : 'Ajouter ami'),
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
                            color: AppColors.secondary.withValues(alpha: 0.15),
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
                        child: StatCard(
                          label: 'ELO',
                          value: '${user?.elo ?? 1000}',
                          icon: Icons.trending_up,
                          valueColor: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatCard(
                          label: 'Victoires',
                          value: '${user?.stats.matchesWon ?? 0}',
                          icon: Icons.emoji_events,
                          valueColor: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatCard(
                          label: 'Defaites',
                          value: '$losses',
                          icon: Icons.close,
                          valueColor: AppColors.error,
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
                        child: StatCard(
                          label: 'Moyenne',
                          value:
                              user?.stats.averageScore.toStringAsFixed(1) ??
                              '0',
                          icon: Icons.analytics,
                          valueColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatCard(
                          label: 'Checkout',
                          value:
                              '${user?.stats.checkoutRate.toStringAsFixed(0) ?? 0}%',
                          icon: Icons.check_circle,
                          valueColor: AppColors.secondary,
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
                        child: StatCard(
                          label: '180s',
                          value: '${user?.stats.highest180s ?? 0}',
                          icon: Icons.stars,
                          valueColor: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatCard(
                          label: '140+',
                          value: '${user?.stats.count140Plus ?? 0}',
                          icon: Icons.local_fire_department,
                          valueColor: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatCard(
                          label: '100+',
                          value: '${user?.stats.count100Plus ?? 0}',
                          icon: Icons.bolt,
                          valueColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: PrecisionSection(userId: isOwnProfile ? null : user?.id),
              ),

              if (isOwnProfile)
                const SliverToBoxAdapter(
                  child: SectionHeader(title: 'Progression ELO'),
                ),
              if (isOwnProfile)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: EloChart(eloHistory: profileState.eloHistory),
                  ),
                ),

              if (isOwnProfile)
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Badges',
                    actionText: 'Voir tout',
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

              if (isOwnProfile)
                const SliverToBoxAdapter(
                  child: SectionHeader(title: 'Historique des matchs'),
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
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}
