import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/config/translation_service.dart';
import '../../../core/network/api_providers.dart';
import '../../../shared/models/match_history_summary.dart';
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
  List<MatchHistorySummary> _visitorRecentMatches = const [];
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
          _visitorRecentMatches = const [];
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
      final recentMatchesFuture = service.fetchRecentMatches(
        userId: widget.userId!,
      );
      final results = await Future.wait([
        userFuture,
        statusFuture,
        recentMatchesFuture,
      ]);
      final user = results[0] as UserModel;
      final status = results[1] as Map<String, bool>;
      final recentMatches = results[2] as List<MatchHistorySummary>;

      if (!mounted) return;
      setState(() {
        _visitorUser = user;
        _visitorRecentMatches = recentMatches;
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

  _StatDeltaData? _buildDelta({
    required double viewerValue,
    required double comparedValue,
    required bool isPercent,
    int digits = 1,
  }) {
    final delta = viewerValue - comparedValue;
    if (delta.abs() < 0.001) {
      return null;
    }

    final positive = delta > 0;
    final absValue = delta.abs();
    final valueLabel = digits == 0
        ? absValue.toStringAsFixed(0)
        : absValue.toStringAsFixed(digits);
    return _StatDeltaData(
      text: '${positive ? '+' : '-'}$valueLabel${isPercent ? '%' : ''}',
      positive: positive,
    );
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
          title: t(
            'SCREEN.PROFILE.REMOVE_FRIEND',
            fallback: 'Retirer cet ami ?',
          ),
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
    final recentMatches = isOwnProfile
        ? profileState.matchHistory.take(5).toList(growable: false)
        : _visitorRecentMatches;
    final viewer = currentUser;
    final showComparison = !isOwnProfile && viewer != null && user != null;
    final matchesDelta = showComparison
        ? _buildDelta(
            viewerValue: viewer.stats.matchesPlayed.toDouble(),
            comparedValue: user.stats.matchesPlayed.toDouble(),
            isPercent: false,
            digits: 0,
          )
        : null;
    final winRateDelta = showComparison
        ? _buildDelta(
            viewerValue: viewer.stats.winRate,
            comparedValue: user.stats.winRate,
            isPercent: true,
          )
        : null;
    final avgDelta = showComparison
        ? _buildDelta(
            viewerValue: viewer.stats.averageScore,
            comparedValue: user.stats.averageScore,
            isPercent: false,
          )
        : null;
    final checkoutDelta = showComparison
        ? _buildDelta(
            viewerValue: viewer.stats.checkoutRate,
            comparedValue: user.stats.checkoutRate,
            isPercent: true,
          )
        : null;
    final bestAvgDelta = showComparison
        ? _buildDelta(
            viewerValue: viewer.stats.bestAverage,
            comparedValue: user.stats.bestAverage,
            isPercent: false,
          )
        : null;
    final total180Delta = showComparison
        ? _buildDelta(
            viewerValue: viewer.stats.highest180s.toDouble(),
            comparedValue: user.stats.highest180s.toDouble(),
            isPercent: false,
            digits: 0,
          )
        : null;
    final highestScoreDelta = showComparison
        ? _buildDelta(
            viewerValue: viewer.stats.highFinish.toDouble(),
            comparedValue: user.stats.highFinish.toDouble(),
            isPercent: false,
            digits: 0,
          )
        : null;
    final winRate = user?.stats.winRate ?? 0.0;
    final est501 = (user?.stats.averageScore ?? 0) * 1.08;
    final est301 = (user?.stats.averageScore ?? 0) * 0.98;
    final estCricket = (user?.stats.checkoutRate ?? 0) * 0.85;
    final showProfileSkeleton =
        isOwnProfile &&
        profileState.isLoading &&
        profileState.matchHistory.isEmpty &&
        profileState.badges.isEmpty;

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

    if (showProfileSkeleton) {
      return AppScaffold(child: const _ProfileLoadingSkeleton());
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
                    child: _ProfileReveal(
                      order: 0,
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
                                    tooltip: t(
                                      'SCREEN.PROFILE.BLOCK',
                                      fallback: 'Bloquer',
                                    ),
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

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.card.withValues(alpha: 0.98),
                                  AppColors.surfaceLight.withValues(alpha: 0.9),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: AppColors.stroke.withValues(alpha: 0.9),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: isOwnProfile
                                          ? _changeAvatar
                                          : null,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          PlayerAvatar(
                                            name: user?.username ?? 'Joueur',
                                            imageUrl: user?.avatarUrl,
                                            size: 72,
                                            showBorder: true,
                                          ),
                                          if (isOwnProfile)
                                            Positioned(
                                              right: -2,
                                              bottom: -2,
                                              child: Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: AppColors.surface,
                                                  border: Border.all(
                                                    color: AppColors.stroke,
                                                    width: 1.1,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.photo_camera,
                                                  size: 12,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user?.username ?? 'Joueur',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            user?.clubName ??
                                                t(
                                                  'SCREEN.PROFILE.NO_CLUB',
                                                  fallback: 'Sans club',
                                                ),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.info,
                                            ),
                                          ),
                                          if (isOwnProfile &&
                                              (user?.email ?? '')
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              user?.email ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textHint,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _CompactMetricTile(
                                        label: t(
                                          'SCREEN.PROFILE.MATCHES',
                                          fallback: 'Matchs',
                                        ),
                                        value:
                                            '${user?.stats.matchesPlayed ?? 0}',
                                        delta: matchesDelta,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _CompactMetricTile(
                                        label: t(
                                          'SCREEN.PROFILE.WINS',
                                          fallback: 'Victoires',
                                        ),
                                        value: '${winRate.toStringAsFixed(0)}%',
                                        valueColor: AppColors.success,
                                        delta: winRateDelta,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _CompactMetricTile(
                                        label: t(
                                          'SCREEN.PROFILE.AVERAGE',
                                          fallback: 'Moyenne',
                                        ),
                                        value:
                                            user?.stats.averageScore
                                                .toStringAsFixed(1) ??
                                            '0.0',
                                        valueColor: AppColors.primary,
                                        delta: avgDelta,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: _ProfileReveal(
                    order: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t(
                              'SCREEN.PROFILE.KEY_PERFORMANCES',
                              fallback: 'Performances cles',
                            ),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1.26,
                            children: [
                              _ProfileStatTile(
                                title: t(
                                  'SCREEN.PROFILE.CHECKOUT',
                                  fallback: 'Checkout %',
                                ),
                                accentIcon: Icons.adjust,
                                delta: checkoutDelta,
                                child: Text(
                                  '${user?.stats.checkoutRate.toStringAsFixed(1) ?? 0}%',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              _ProfileStatTile(
                                title: t(
                                  'SCREEN.PROFILE.BEST_AVG',
                                  fallback: 'Meilleure moyenne',
                                ),
                                accentIcon: Icons.bolt,
                                delta: bestAvgDelta,
                                child: Text(
                                  user?.stats.bestAverage.toStringAsFixed(1) ??
                                      '0.0',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              _ProfileStatTile(
                                title: t(
                                  'SCREEN.PROFILE.SHOTS_180',
                                  fallback: 'Total 180s',
                                ),
                                accentLabel: 'MAX',
                                accentLabelColor: AppColors.error,
                                delta: total180Delta,
                                child: Text(
                                  '${user?.stats.highest180s ?? 0}',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              _ProfileStatTile(
                                title: t(
                                  'SCREEN.PROFILE.HIGHEST_SCORE',
                                  fallback: 'Highest score',
                                ),
                                accentIcon: Icons.local_fire_department,
                                accentIconColor: AppColors.secondary,
                                delta: highestScoreDelta,
                                child: Text(
                                  '${user?.stats.highFinish ?? 0}',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.stroke),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t(
                                    'SCREEN.PROFILE.FORMAT_PERFORMANCE',
                                    fallback: 'Performance par format',
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _FormatLine(
                                  label: '501',
                                  value: est501.clamp(0, 100).toDouble(),
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 10),
                                _FormatLine(
                                  label: '301',
                                  value: est301.clamp(0, 100).toDouble(),
                                  color: AppColors.info,
                                ),
                                const SizedBox(height: 10),
                                _FormatLine(
                                  label: 'Cricket',
                                  value: estCricket.clamp(0, 100).toDouble(),
                                  color: AppColors.secondary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                if (isOwnProfile)
                  SliverToBoxAdapter(
                    child: _ProfileReveal(
                      order: 2,
                      child: SectionHeader(
                        title: t(
                          'SCREEN.PROFILE.ELO_PROGRESSION',
                          fallback: 'Progression ELO',
                        ),
                      ),
                    ),
                  ),
                if (isOwnProfile)
                  SliverToBoxAdapter(
                    child: _ProfileReveal(
                      order: 3,
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
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                SliverToBoxAdapter(
                  child: _ProfileReveal(
                    order: 4,
                    child: PrecisionSection(
                      userId: isOwnProfile ? null : user?.id,
                    ),
                  ),
                ),

                if (recentMatches.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _ProfileReveal(
                      order: 5,
                      child: SectionHeader(
                        title: t(
                          'SCREEN.PROFILE.HISTORY',
                          fallback: 'Historique des matchs',
                        ),
                        actionText: isOwnProfile
                            ? t('SCREEN.HOME.VIEW_ALL', fallback: 'Voir tout')
                            : null,
                        onAction: isOwnProfile
                            ? () => context.push(AppRoutes.matchHistory)
                            : null,
                      ),
                    ),
                  ),
                if (recentMatches.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _ProfileReveal(
                      order: 6,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: MatchHistoryList(
                          matches: recentMatches,
                          onMatchTap: (matchId) =>
                              context.push('/match/$matchId/report'),
                        ),
                      ),
                    ),
                  ),
                if (isOwnProfile)
                  SliverToBoxAdapter(
                    child: _ProfileReveal(
                      order: 7,
                      child: SectionHeader(
                        title: t('SCREEN.PROFILE.BADGES', fallback: 'Badges'),
                        actionText: t(
                          'SCREEN.HOME.VIEW_ALL',
                          fallback: 'Voir tout',
                        ),
                        onAction: () => context.push(AppRoutes.badges),
                      ),
                    ),
                  ),
                if (isOwnProfile)
                  SliverToBoxAdapter(
                    child: _ProfileReveal(
                      order: 8,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: BadgeGrid(
                          badges: profileState.badges,
                          maxDisplay: 4,
                        ),
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
  const _ProfileStatTile({
    required this.title,
    required this.child,
    this.accentIcon,
    this.accentIconColor,
    this.accentLabel,
    this.accentLabelColor,
    this.delta,
  });

  final String title;
  final Widget child;
  final IconData? accentIcon;
  final Color? accentIconColor;
  final String? accentLabel;
  final Color? accentLabelColor;
  final _StatDeltaData? delta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (accentLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (accentLabelColor ?? AppColors.error).withValues(
                      alpha: 0.2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    accentLabel!,
                    style: TextStyle(
                      color: accentLabelColor ?? AppColors.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (accentIcon != null)
                Icon(
                  accentIcon,
                  size: 16,
                  color: accentIconColor ?? AppColors.warning,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Align(alignment: Alignment.bottomLeft, child: child),
          ),
          if (delta != null)
            Align(
              alignment: Alignment.bottomRight,
              child: _StatDeltaChip(data: delta!),
            ),
        ],
      ),
    );
  }
}

class _CompactMetricTile extends StatelessWidget {
  const _CompactMetricTile({
    required this.label,
    required this.value,
    this.valueColor,
    this.delta,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final _StatDeltaData? delta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (delta != null)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _StatDeltaChip(data: delta!),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatDeltaData {
  const _StatDeltaData({required this.text, required this.positive});

  final String text;
  final bool positive;
}

class _StatDeltaChip extends StatelessWidget {
  const _StatDeltaChip({required this.data});

  final _StatDeltaData data;

  @override
  Widget build(BuildContext context) {
    final color = data.positive ? AppColors.success : AppColors.error;
    final icon = data.positive ? Icons.arrow_drop_up : Icons.arrow_drop_down;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        Text(
          data.text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _FormatLine extends StatelessWidget {
  const _FormatLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${value.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: (value / 100).clamp(0, 1),
            backgroundColor: AppColors.background.withValues(alpha: 0.8),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ProfileReveal extends StatelessWidget {
  const _ProfileReveal({required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = (order * 70).clamp(0, 560);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, widget) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: widget,
          ),
        );
      },
      child: child,
    );
  }
}

class _ProfileLoadingSkeleton extends StatelessWidget {
  const _ProfileLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceLight,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 10),
          const CircleAvatar(radius: 45, backgroundColor: Colors.white),
          const SizedBox(height: 14),
          Center(child: Container(width: 140, height: 16, color: Colors.white)),
          const SizedBox(height: 18),
          Row(
            children: List.generate(
              2,
              (_) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 94,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              3,
              (_) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 94,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(height: 180, color: Colors.white),
          const SizedBox(height: 16),
          Container(height: 120, color: Colors.white),
          const SizedBox(height: 16),
          Container(height: 140, color: Colors.white),
        ],
      ),
    );
  }
}
