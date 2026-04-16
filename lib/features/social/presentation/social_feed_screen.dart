import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../../core/config/translation_service.dart';
import '../../../shared/widgets/neon_modal.dart';
import '../../../shared/widgets/player_avatar.dart';
import '../controller/social_feed_controller.dart';
import '../models/social_feed_post.dart';

enum _PostQuickAction { report, openProfile }

class SocialFeedScreen extends ConsumerStatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  ConsumerState<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends ConsumerState<SocialFeedScreen> {
  late final ScrollController _scrollController;
  final Set<String> _expandedComments = <String>{};

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

  void _toggleComments(String postId) {
    setState(() {
      if (_expandedComments.contains(postId)) {
        _expandedComments.remove(postId);
      } else {
        _expandedComments.add(postId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(socialFeedControllerProvider);

    return Container(
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
                        child: _TimelineFeedItem(
                          index: i,
                          isLast: i == state.posts.length - 1,
                          child: _FeedCard(
                            post: state.posts[i],
                            commentsExpanded: _expandedComments.contains(
                              state.posts[i].id,
                            ),
                            onToggleComments: () =>
                                _toggleComments(state.posts[i].id),
                          ),
                        ),
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

class _TimelineFeedItem extends StatelessWidget {
  const _TimelineFeedItem({
    required this.index,
    required this.isLast,
    required this.child,
  });

  final int index;
  final bool isLast;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 11,
                height: 11,
                margin: const EdgeInsets.only(top: 18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.95),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 126 + (index.isEven ? 8 : 0),
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.58),
                        AppColors.secondary.withValues(alpha: 0.12),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }
}

class _FeedCard extends ConsumerWidget {
  const _FeedCard({
    required this.post,
    required this.commentsExpanded,
    required this.onToggleComments,
  });

  final SocialFeedPost post;
  final bool commentsExpanded;
  final VoidCallback onToggleComments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () =>
                        context.push(AppRoutes.profile, extra: post.authorId),
                    child: PlayerAvatar(
                      imageUrl: post.authorAvatarUrl,
                      name: post.authorName,
                      size: 38,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () =>
                          context.push(AppRoutes.profile, extra: post.authorId),
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
                  ),
                  IconButton(
                    onPressed: () => _showPostActions(context, ref),
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: AppColors.textSecondary,
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_buildScoreContent()],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => ref
                        .read(socialFeedControllerProvider.notifier)
                        .toggleLike(post.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            post.isLikedByCurrentUser
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: post.isLikedByCurrentUser
                                ? AppColors.error
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${post.likesCount}',
                            style: GoogleFonts.manrope(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onToggleComments,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            commentsExpanded
                                ? Icons.mode_comment
                                : Icons.mode_comment_outlined,
                            color: commentsExpanded
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${post.commentsCount}',
                            style: GoogleFonts.manrope(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (commentsExpanded) ...[
                const SizedBox(height: 10),
                _CommentsPanel(post: post),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreContent() {
    final parsedScore = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(
      post.setsScore.trim(),
    );
    final fallbackP1Score = parsedScore != null
        ? int.tryParse(parsedScore.group(1) ?? '')
        : null;
    final fallbackP2Score = parsedScore != null
        ? int.tryParse(parsedScore.group(2) ?? '')
        : null;

    final leftName = (post.player1Name?.trim().isNotEmpty ?? false)
        ? post.player1Name!.trim()
        : post.authorName;
    final rightName = (post.player2Name?.trim().isNotEmpty ?? false)
        ? post.player2Name!.trim()
        : t('SCREEN.SOCIAL.OPPONENT', fallback: 'Adversaire');

    final leftScore = post.player1Score ?? fallbackP1Score;
    final rightScore = post.player2Score ?? fallbackP2Score;
    final hasLine1 = leftScore != null && rightScore != null;

    final p1Winner = hasLine1
        ? leftScore > rightScore
        : post.resultLabel.toLowerCase() == 'victoire';
    final p2Winner = hasLine1
        ? rightScore > leftScore
        : post.resultLabel.toLowerCase() == 'defaite';

    final averageText = post.matchAverage == null
        ? '--'
        : post.matchAverage!.toStringAsFixed(1);
    final checkoutText = post.matchCheckoutRate == null
        ? '--'
        : '${post.matchCheckoutRate!.toStringAsFixed(1)}%';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            children: [
              TextSpan(
                text: hasLine1
                    ? '$leftName $leftScore'
                    : '$leftName ${post.setsScore}',
                style: TextStyle(
                  color: p1Winner ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              const TextSpan(text: ' - '),
              TextSpan(
                text: hasLine1 ? '$rightScore $rightName' : rightName,
                style: TextStyle(
                  color: p2Winner ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Moyenne $averageText • Checkout $checkoutText',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Future<void> _showPostActions(BuildContext context, WidgetRef ref) async {
    final action = await showNeonDialog<_PostQuickAction>(
      context: context,
      builder: (dialogContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('SCREEN.SOCIAL.POST_ACTIONS', fallback: 'Actions du post'),
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(
                  _PostQuickAction.report,
                ),
                icon: const Icon(Icons.flag_outlined),
                label: Text(
                  t('SCREEN.SOCIAL.REPORT_POST', fallback: 'Signaler'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(
                  _PostQuickAction.openProfile,
                ),
                icon: const Icon(Icons.person_outline),
                label: Text(
                  t('SCREEN.SOCIAL.OPEN_AUTHOR_PROFILE', fallback: 'Voir le profil'),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) {
      return;
    }

    if (action == _PostQuickAction.openProfile) {
      context.push(AppRoutes.profile, extra: post.authorId);
      return;
    }

    final reason = await _askReportReason(context);
    if (!context.mounted || reason == null) {
      return;
    }

    final ok = await ref
        .read(socialFeedControllerProvider.notifier)
        .reportPost(postId: post.id, reason: reason);
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? t('SCREEN.SOCIAL.REPORT_SUCCESS', fallback: 'Post signale.')
              : t(
                  'SCREEN.SOCIAL.REPORT_FAILED',
                  fallback: 'Impossible de signaler ce post.',
                ),
        ),
      ),
    );
  }

  Future<String?> _askReportReason(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showNeonDialog<String>(
      context: context,
      builder: (dialogContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('SCREEN.SOCIAL.REPORT_REASON_TITLE', fallback: 'Motif du signalement'),
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: t(
                  'SCREEN.SOCIAL.REPORT_REASON_HINT',
                  fallback: 'Expliquez brievement le probleme...',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(t('COMMON.CANCEL', fallback: 'Annuler')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(controller.text.trim()),
                    child: Text(t('SCREEN.SOCIAL.REPORT_POST', fallback: 'Signaler')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (reason == null || reason.trim().isEmpty) {
      return null;
    }
    return reason.trim();
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

class _CommentsPanel extends ConsumerStatefulWidget {
  const _CommentsPanel({required this.post});

  final SocialFeedPost post;

  @override
  ConsumerState<_CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends ConsumerState<_CommentsPanel> {
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    await ref
        .read(socialFeedControllerProvider.notifier)
        .addComment(
          postId: widget.post.id,
          message: _commentController.text,
        );
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(
      socialFeedControllerProvider.select(
        (state) => state.posts.firstWhere(
          (item) => item.id == widget.post.id,
          orElse: () => widget.post,
        ),
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.stroke.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.comments.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                t(
                  'SCREEN.SOCIAL.NO_COMMENTS',
                  fallback: 'Aucun commentaire pour le moment.',
                ),
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            )
          else ...[
            for (var i = 0; i < post.comments.length; i++) ...[
              _CommentRow(comment: post.comments[i]),
              if (i != post.comments.length - 1)
                Divider(
                  height: 14,
                  color: AppColors.stroke.withValues(alpha: 0.7),
                ),
            ],
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  minLines: 1,
                  maxLines: 2,
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    hintText: t(
                      'SCREEN.SOCIAL.WRITE_COMMENT',
                      fallback: 'Ecrire un commentaire...',
                    ),
                    hintStyle: GoogleFonts.manrope(
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: AppColors.card.withValues(alpha: 0.7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.stroke.withValues(alpha: 0.9),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.stroke.withValues(alpha: 0.9),
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 1.1,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _submitComment(),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _submitComment,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.2),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.6),
                    ),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});

  final SocialFeedComment comment;

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(comment.createdAt);
    final timeLabel = diff.inMinutes < 1
        ? t('SCREEN.SOCIAL.NOW', fallback: 'A l\'instant')
        : (diff.inHours < 1 ? '${diff.inMinutes} min' : '${diff.inHours} h');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                comment.authorName,
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              timeLabel,
              style: GoogleFonts.manrope(
                color: AppColors.textHint,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          comment.message,
          style: GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
