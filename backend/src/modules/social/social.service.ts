import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { normalizeLimit } from '../../common/utils/normalize-limit';
import { Friendship } from '../contacts/entities/friendship.entity';
import { Match } from '../matches/entities/match.entity';
import { MatchPlayer } from '../matches/entities/match-player.entity';
import { SocialPost } from './entities/social-post.entity';

@Injectable()
export class SocialService {
  constructor(
    @InjectRepository(SocialPost)
    private readonly socialPostRepo: Repository<SocialPost>,
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

    return posts.map((post) => this.serializePost(post));
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

  private serializePost(post: SocialPost) {
    return {
      id: post.id,
      match_id: post.match_id,
      mode: post.mode,
      sets_score: post.sets_score,
      result_label: post.result_label,
      description: post.description,
      created_at: post.created_at,
      author: {
        id: post.author?.id ?? post.author_id,
        username: post.author?.username ?? 'Joueur',
        avatar_url: post.author?.avatar_url ?? null,
      },
    };
  }
}
