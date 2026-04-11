import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/config/translation_service.dart';
import '../../../shared/widgets/player_avatar.dart';
import '../controller/social_feed_controller.dart';
import '../models/social_feed_post.dart';

class SocialFeedScreen extends ConsumerStatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  ConsumerState<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends ConsumerState<SocialFeedScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(socialFeedControllerProvider.notifier).loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final threshold = _scrollController.position.maxScrollExtent - 320;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(socialFeedControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(socialFeedControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          t('SCREEN.SOCIAL.TITLE', fallback: 'Fil d\'actualite'),
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.notifications),
            icon: const Icon(Icons.notifications_outlined),
            tooltip: t('SCREEN.NOTIFICATIONS.TITLE', fallback: 'Notifications'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(socialFeedControllerProvider.notifier).refresh(),
          child: state.isLoading
              ? const _FeedSkeletonList()
              : state.posts.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 120),
                    Icon(
                      Icons.newspaper_rounded,
                      size: 62,
                      color: AppColors.textHint.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      t(
                        'SCREEN.SOCIAL.EMPTY',
                        fallback: 'Aucune activite de vos amis pour le moment.',
                      ),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
              : ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  children: [
                    if (state.error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          state.error!,
                          style: GoogleFonts.manrope(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    for (var i = 0; i < state.posts.length; i++)
                      _AnimatedFeedItem(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _FeedCard(post: state.posts[i]),
                        ),
                      ),
                    if (state.isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AnimatedFeedItem extends StatelessWidget {
  const _AnimatedFeedItem({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = (index * 55).clamp(0, 380);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, widget) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: widget,
          ),
        );
      },
      child: child,
    );
  }
}

class _FeedSkeletonList extends StatelessWidget {
  const _FeedSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      itemCount: 6,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: _FeedSkeletonCard(),
      ),
    );
  }
}

class _FeedSkeletonCard extends StatelessWidget {
  const _FeedSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceLight,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 12, width: 120, color: Colors.white),
                      const SizedBox(height: 6),
                      Container(height: 10, width: 80, color: Colors.white),
                    ],
                  ),
                ),
                Container(
                  height: 22,
                  width: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 11, width: double.infinity, color: Colors.white),
            const SizedBox(height: 8),
            Container(height: 11, width: 210, color: Colors.white),
            const SizedBox(height: 12),
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.post});

  final SocialFeedPost post;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        final route = AppRoutes.matchReport.replaceFirst(':id', post.matchId);
        context.push(route);
      },
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.stroke),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PlayerAvatar(
                    imageUrl: post.authorAvatarUrl,
                    name: post.authorName,
                    size: 38,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: GoogleFonts.manrope(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _relativeDate(post.createdAt),
                          style: GoogleFonts.manrope(
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: post.resultLabel.toLowerCase().contains('vic')
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      post.resultLabel,
                      style: GoogleFonts.manrope(
                        color: post.resultLabel.toLowerCase().contains('vic')
                            ? AppColors.success
                            : AppColors.error,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              if (post.description.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  post.description,
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surfaceLight.withValues(alpha: 0.95),
                      AppColors.surface.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    _pill(post.mode),
                    const SizedBox(width: 8),
                    _pill(post.setsScore),
                    const Spacer(),
                    Text(
                      t('SCREEN.SOCIAL.OPEN_REPORT', fallback: 'Voir rapport'),
                      style: GoogleFonts.manrope(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) {
      return t('SCREEN.SOCIAL.NOW', fallback: 'A l\'instant');
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} h';
    }
    return '${diff.inDays} j';
  }
}
