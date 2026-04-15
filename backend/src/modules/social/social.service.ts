import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { normalizeLimit } from '../../common/utils/normalize-limit';
import { Friendship } from '../contacts/entities/friendship.entity';
import { Match } from '../matches/entities/match.entity';
import { MatchPlayer } from '../matches/entities/match-player.entity';
import { CreateSocialCommentDto } from './dto/create-social-comment.dto';
import { SocialPostComment } from './entities/social-post-comment.entity';
import { SocialPostLike } from './entities/social-post-like.entity';
import { SocialPost } from './entities/social-post.entity';

type SerializedSocialComment = {
  id: string;
  message: string;
  created_at: Date;
  author: {
    id: string;
    username: string;
    avatar_url: string | null;
  };
};

@Injectable()
export class SocialService {
  constructor(
    @InjectRepository(SocialPost)
    private readonly socialPostRepo: Repository<SocialPost>,
    @InjectRepository(SocialPostLike)
    private readonly socialPostLikeRepo: Repository<SocialPostLike>,
    @InjectRepository(SocialPostComment)
    private readonly socialPostCommentRepo: Repository<SocialPostComment>,
    @InjectRepository(Friendship)
    private readonly friendshipRepo: Repository<Friendship>,
    @InjectRepository(Match)
    private readonly matchRepo: Repository<Match>,
  ) {}

  async createPost(
    userId: string,
    body: { match_id: string; description?: string },
  ) {
    const matchId = body.match_id?.trim();
    if (!matchId) {
      throw new BadRequestException('match_id is required');
    }

    const match = await this.matchRepo.findOne({
      where: { id: matchId },
      relations: ['players', 'players.user', 'sets'],
    });

    if (!match) {
      throw new NotFoundException('Match not found');
    }

    const orderedPlayers = this.getOrderedPlayers(match.players ?? []);
    const author = orderedPlayers.find((player) => player.user_id === userId);
    if (!author) {
      throw new BadRequestException('You are not a player in this match');
    }

    const { setsScore, resultLabel } = this.computeMatchResult(
      match,
      orderedPlayers,
      userId,
    );

    const post = this.socialPostRepo.create({
      author_id: userId,
      match_id: match.id,
      mode: match.mode,
      sets_score: setsScore,
      result_label: resultLabel,
      description: (body.description ?? '').trim() || null,
    });

    const saved = await this.socialPostRepo.save(post);
    const row = await this.socialPostRepo.findOne({
      where: { id: saved.id },
      relations: ['author'],
    });

    if (!row) {
      throw new NotFoundException('Post not found after creation');
    }

    return this.serializePost(row);
  }

  async listFeed(userId: string, limit = 10, offset = 0) {
    const take = normalizeLimit(limit, 10);
    const skip = Math.max(0, Math.floor(offset || 0));

    const friendships = await this.friendshipRepo.find({
      where: { user_id: userId },
      select: ['friend_id'],
    });

    const allowedAuthors = [
      userId,
      ...friendships.map((friendship) => friendship.friend_id),
    ];

    if (allowedAuthors.length === 0) {
      return [];
    }

    const posts = await this.socialPostRepo
      .createQueryBuilder('p')
      .leftJoinAndSelect('p.author', 'author')
      .where('p.author_id IN (:...allowedAuthors)', { allowedAuthors })
      .orderBy('p.created_at', 'DESC')
      .skip(skip)
      .take(take)
      .getMany();

    const postIds = posts.map((post) => post.id);
    const { likesCountByPost, likedByMePostIds, commentsByPost } =
      await this.loadInteractions(userId, postIds);

    return posts.map((post) =>
      this.serializePost(post, {
        likesCount: likesCountByPost.get(post.id) ?? 0,
        likedByMe: likedByMePostIds.has(post.id),
        comments: commentsByPost.get(post.id) ?? [],
      }),
    );
  }

  async likePost(userId: string, postId: string) {
    await this.ensurePostExists(postId);

    try {
      const like = this.socialPostLikeRepo.create({
        post_id: postId,
        user_id: userId,
      });
      await this.socialPostLikeRepo.save(like);
    } catch (error: unknown) {
      const pgError = error as { code?: string };
      if (pgError.code !== '23505') {
        throw new ConflictException('Unable to like post');
      }
    }

    const likesCount = await this.socialPostLikeRepo.count({
      where: { post_id: postId },
    });

    return {
      post_id: postId,
      likes_count: likesCount,
      liked_by_me: true,
    };
  }

  async unlikePost(userId: string, postId: string) {
    await this.ensurePostExists(postId);

    await this.socialPostLikeRepo.delete({
      post_id: postId,
      user_id: userId,
    });

    const likesCount = await this.socialPostLikeRepo.count({
      where: { post_id: postId },
    });

    return {
      post_id: postId,
      likes_count: likesCount,
      liked_by_me: false,
    };
  }

  async addComment(userId: string, postId: string, dto: CreateSocialCommentDto) {
    await this.ensurePostExists(postId);

    const message = dto.message?.trim();
    if (!message) {
      throw new BadRequestException('message is required');
    }

    const comment = this.socialPostCommentRepo.create({
      post_id: postId,
      author_id: userId,
      message,
    });
    const saved = await this.socialPostCommentRepo.save(comment);

    const row = await this.socialPostCommentRepo.findOne({
      where: { id: saved.id },
      relations: ['author'],
    });

    if (!row) {
      throw new NotFoundException('Comment not found after creation');
    }

    const commentsCount = await this.socialPostCommentRepo.count({
      where: { post_id: postId },
    });

    return {
      post_id: postId,
      comments_count: commentsCount,
      comment: this.serializeComment(row),
    };
  }

  private async ensurePostExists(postId: string) {
    const post = await this.socialPostRepo.findOne({ where: { id: postId } });
    if (!post) {
      throw new NotFoundException('Post not found');
    }
  }

  private async loadInteractions(userId: string, postIds: string[]) {
    if (postIds.length == 0) {
      return {
        likesCountByPost: new Map<string, number>(),
        likedByMePostIds: new Set<string>(),
        commentsByPost: new Map<string, SerializedSocialComment[]>(),
      };
    }

    const likesRaw = await this.socialPostLikeRepo
      .createQueryBuilder('l')
      .select('l.post_id', 'post_id')
      .addSelect('COUNT(*)::int', 'likes_count')
      .where('l.post_id IN (:...postIds)', { postIds })
      .groupBy('l.post_id')
      .getRawMany<{ post_id: string; likes_count: string }>();

    const myLikes = await this.socialPostLikeRepo
      .createQueryBuilder('l')
      .select('l.post_id', 'post_id')
      .where('l.user_id = :userId', { userId })
      .andWhere('l.post_id IN (:...postIds)', { postIds })
      .getRawMany<{ post_id: string }>();

    const comments = await this.socialPostCommentRepo
      .createQueryBuilder('c')
      .leftJoinAndSelect('c.author', 'author')
      .where('c.post_id IN (:...postIds)', { postIds })
      .orderBy('c.created_at', 'DESC')
      .getMany();

    const likesCountByPost = new Map<string, number>();
    for (const row of likesRaw) {
      likesCountByPost.set(row.post_id, Number(row.likes_count) || 0);
    }

    const postIdSet = new Set(postIds);
    const likedByMePostIds = new Set(
      myLikes.map((like) => like.post_id).filter((postId) => postIdSet.has(postId)),
    );

    const commentsByPost = new Map<
      string,
      SerializedSocialComment[]
    >();
    for (const comment of comments) {
      const existing = commentsByPost.get(comment.post_id) ?? [];
      existing.push(this.serializeComment(comment));
      commentsByPost.set(comment.post_id, existing);
    }

    return { likesCountByPost, likedByMePostIds, commentsByPost };
  }

  private getOrderedPlayers(players: MatchPlayer[]) {
    const sideRank = (side: string) => (side === 'home' ? 0 : 1);
    return [...players].sort((a, b) => sideRank(a.side) - sideRank(b.side));
  }

  private computeMatchResult(
    match: Match,
    orderedPlayers: MatchPlayer[],
    userId: string,
  ) {
    const home = orderedPlayers[0];
    const away = orderedPlayers[1];

    const homeSets = (match.sets ?? []).filter(
      (set) => set.winner_id === home?.user_id,
    ).length;
    const awaySets = (match.sets ?? []).filter(
      (set) => set.winner_id === away?.user_id,
    ).length;

    const setsScore = `${homeSets} - ${awaySets}`;

    let winnerId: string | null = null;
    if (homeSets > awaySets) {
      winnerId = home?.user_id ?? null;
    } else if (awaySets > homeSets) {
      winnerId = away?.user_id ?? null;
    }

    const resultLabel = !winnerId
      ? 'Match'
      : winnerId === userId
        ? 'Victoire'
        : 'Defaite';

    return { setsScore, resultLabel };
  }

  private serializePost(
    post: SocialPost,
    interactions?: {
      likesCount?: number;
      likedByMe?: boolean;
      comments?: SerializedSocialComment[];
    },
  ) {
    return {
      id: post.id,
      match_id: post.match_id,
      mode: post.mode,
      sets_score: post.sets_score,
      result_label: post.result_label,
      description: post.description,
      created_at: post.created_at,
      likes_count: interactions?.likesCount ?? 0,
      comments_count: interactions?.comments?.length ?? 0,
      liked_by_me: interactions?.likedByMe ?? false,
      comments: interactions?.comments ?? [],
      author: {
        id: post.author?.id ?? post.author_id,
        username: post.author?.username ?? 'Joueur',
        avatar_url: post.author?.avatar_url ?? null,
      },
    };
  }

  private serializeComment(comment: SocialPostComment): SerializedSocialComment {
    return {
      id: comment.id,
      message: comment.message,
      created_at: comment.created_at,
      author: {
        id: comment.author?.id ?? comment.author_id,
        username: comment.author?.username ?? 'Joueur',
        avatar_url: comment.author?.avatar_url ?? null,
      },
    };
  }
}
