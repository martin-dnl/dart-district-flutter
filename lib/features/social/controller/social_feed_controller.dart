import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../auth/controller/auth_controller.dart';
import '../../match/models/match_report_data.dart';
import '../data/social_feed_service.dart';
import '../models/social_feed_post.dart';

class SocialFeedState {
  const SocialFeedState({
    this.posts = const <SocialFeedPost>[],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSharing = false,
    this.offset = 0,
    this.hasMore = true,
    this.error,
  });

  final List<SocialFeedPost> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSharing;
  final int offset;
  final bool hasMore;
  final String? error;

  SocialFeedState copyWith({
    List<SocialFeedPost>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSharing,
    int? offset,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return SocialFeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSharing: isSharing ?? this.isSharing,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SocialFeedController extends StateNotifier<SocialFeedState> {
  SocialFeedController(this._ref)
    : _service = SocialFeedService(_ref.read(apiClientProvider)),
      super(const SocialFeedState());

  final Ref _ref;
  final SocialFeedService _service;
  static const int _pageSize = 10;

  Future<void> loadInitial() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      state = state.copyWith(
        posts: const <SocialFeedPost>[],
        isLoading: false,
        hasMore: false,
        clearError: true,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      posts: const <SocialFeedPost>[],
      hasMore: true,
      offset: 0,
      clearError: true,
    );

    try {
      final posts = await _service.fetchFeed(
        currentUserId: user.id,
        limit: _pageSize,
        offset: 0,
      );

      state = state.copyWith(
        isLoading: false,
        posts: posts,
        hasMore: posts.length == _pageSize,
        offset: posts.length,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Impossible de charger le fil.',
      );
    }
  }

  Future<void> loadMore() async {
    final user = _ref.read(currentUserProvider);
    if (user == null || state.isLoadingMore || !state.hasMore) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final batch = await _service.fetchFeed(
        currentUserId: user.id,
        limit: _pageSize,
        offset: state.offset,
      );

      state = state.copyWith(
        isLoadingMore: false,
        posts: [...state.posts, ...batch],
        offset: state.offset + batch.length,
        hasMore: batch.length == _pageSize,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingMore: false,
        error: 'Chargement supplementaire indisponible.',
      );
    }
  }

  Future<void> refresh() {
    return loadInitial();
  }

  Future<void> toggleLike(String postId) async {
    final previous = state.posts;

    final optimistic = previous
        .map((post) {
          if (post.id != postId) {
            return post;
          }

          final nextLiked = !post.isLikedByCurrentUser;
          final nextLikes = (post.likesCount + (nextLiked ? 1 : -1)).clamp(
            0,
            999999,
          );
          return post.copyWith(
            isLikedByCurrentUser: nextLiked,
            likesCount: nextLikes,
          );
        })
        .toList(growable: false);

    state = state.copyWith(posts: optimistic, clearError: true);

    final postAfterOptimistic = optimistic.firstWhere(
      (post) => post.id == postId,
      orElse: () => previous.firstWhere((post) => post.id == postId),
    );

    try {
      if (postAfterOptimistic.isLikedByCurrentUser) {
        await _service.likePost(postId);
      } else {
        await _service.unlikePost(postId);
      }
    } catch (_) {
      state = state.copyWith(
        posts: previous,
        error: 'Action like indisponible pour le moment.',
      );
    }
  }

  Future<void> addComment({
    required String postId,
    required String message,
  }) async {
    final content = message.trim();
    if (content.isEmpty) {
      return;
    }

    try {
      final comment = await _service.addComment(postId: postId, message: content);
      final updated = state.posts
          .map((post) {
            if (post.id != postId) {
              return post;
            }

            return post.copyWith(
              comments: [comment, ...post.comments],
              commentsCount: post.commentsCount + 1,
            );
          })
          .toList(growable: false);

      state = state.copyWith(posts: updated, clearError: true);
    } catch (_) {
      state = state.copyWith(
        error: 'Commentaire indisponible pour le moment.',
      );
    }
  }

  Future<bool> reportPost({
    required String postId,
    required String reason,
  }) async {
    final content = reason.trim();
    if (content.isEmpty) {
      return false;
    }

    try {
      await _service.reportPost(postId: postId, reason: content);
      state = state.copyWith(clearError: true);
      return true;
    } catch (_) {
      state = state.copyWith(
        error: 'Signalement impossible pour le moment.',
      );
      return false;
    }
  }

  Future<bool> shareMatchReport(
    MatchReportData report,
    String description,
  ) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      return false;
    }

    state = state.copyWith(isSharing: true, clearError: true);

    try {
      final resultLabel = report.winnerIndex == 0 ? 'Victoire' : 'Defaite';
      await _service.shareMatch(
        currentUserId: user.id,
        currentUsername: user.username,
        currentUserAvatarUrl: user.avatarUrl,
        matchId: report.matchId,
        mode: report.mode,
        setsScore: report.setsScore,
        resultLabel: resultLabel,
        description: description.trim(),
      );
      state = state.copyWith(isSharing: false, clearError: true);
      await loadInitial();
      return true;
    } catch (_) {
      state = state.copyWith(
        isSharing: false,
        error: 'Partage impossible pour le moment.',
      );
      return false;
    }
  }
}

final socialFeedControllerProvider =
    StateNotifierProvider<SocialFeedController, SocialFeedState>((ref) {
      final controller = SocialFeedController(ref);
      return controller;
    });
