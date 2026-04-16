"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SocialService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const normalize_limit_1 = require("../../common/utils/normalize-limit");
const friendship_entity_1 = require("../contacts/entities/friendship.entity");
const match_entity_1 = require("../matches/entities/match.entity");
const social_post_comment_entity_1 = require("./entities/social-post-comment.entity");
const social_post_like_entity_1 = require("./entities/social-post-like.entity");
const social_post_entity_1 = require("./entities/social-post.entity");
const social_post_report_entity_1 = require("./entities/social-post-report.entity");
let SocialService = class SocialService {
    constructor(socialPostRepo, socialPostLikeRepo, socialPostCommentRepo, socialPostReportRepo, friendshipRepo, matchRepo) {
        this.socialPostRepo = socialPostRepo;
        this.socialPostLikeRepo = socialPostLikeRepo;
        this.socialPostCommentRepo = socialPostCommentRepo;
        this.socialPostReportRepo = socialPostReportRepo;
        this.friendshipRepo = friendshipRepo;
        this.matchRepo = matchRepo;
    }
    async createPost(userId, body) {
        const matchId = body.match_id?.trim();
        if (!matchId) {
            throw new common_1.BadRequestException('match_id is required');
        }
        const match = await this.matchRepo.findOne({
            where: { id: matchId },
            relations: ['players', 'players.user', 'sets', 'sets.legs', 'sets.legs.throws'],
        });
        if (!match) {
            throw new common_1.NotFoundException('Match not found');
        }
        const orderedPlayers = this.getOrderedPlayers(match.players ?? []);
        const author = orderedPlayers.find((player) => player.user_id === userId);
        if (!author) {
            throw new common_1.BadRequestException('You are not a player in this match');
        }
        const { setsScore, resultLabel, winnerId, homeSets, awaySets } = this.computeMatchResult(match, orderedPlayers, userId);
        const matchStats = this.computeMatchGlobalStats(match);
        const home = orderedPlayers[0];
        const away = orderedPlayers[1];
        const post = this.socialPostRepo.create({
            author_id: userId,
            match_id: match.id,
            mode: match.mode,
            sets_score: setsScore,
            result_label: resultLabel,
            description: (body.description ?? '').trim() || null,
            player_1_name: home?.user?.username ?? 'Joueur 1',
            player_1_score: homeSets,
            player_2_name: away?.user?.username ?? 'Joueur 2',
            player_2_score: awaySets,
            winner_user_id: winnerId,
            match_average: matchStats.average,
            match_checkout_rate: matchStats.checkoutRate,
        });
        const saved = await this.socialPostRepo.save(post);
        const row = await this.socialPostRepo.findOne({
            where: { id: saved.id },
            relations: ['author'],
        });
        if (!row) {
            throw new common_1.NotFoundException('Post not found after creation');
        }
        return this.serializePost(row);
    }
    async listFeed(userId, limit = 10, offset = 0) {
        const take = (0, normalize_limit_1.normalizeLimit)(limit, 10);
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
        const { likesCountByPost, likedByMePostIds, commentsByPost } = await this.loadInteractions(userId, postIds);
        return posts.map((post) => this.serializePost(post, {
            likesCount: likesCountByPost.get(post.id) ?? 0,
            likedByMe: likedByMePostIds.has(post.id),
            comments: commentsByPost.get(post.id) ?? [],
        }));
    }
    async likePost(userId, postId) {
        await this.ensurePostExists(postId);
        try {
            const like = this.socialPostLikeRepo.create({
                post_id: postId,
                user_id: userId,
            });
            await this.socialPostLikeRepo.save(like);
        }
        catch (error) {
            const pgError = error;
            if (pgError.code !== '23505') {
                throw new common_1.ConflictException('Unable to like post');
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
    async unlikePost(userId, postId) {
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
    async addComment(userId, postId, dto) {
        await this.ensurePostExists(postId);
        const message = dto.message?.trim();
        if (!message) {
            throw new common_1.BadRequestException('message is required');
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
            throw new common_1.NotFoundException('Comment not found after creation');
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
    async reportPost(userId, postId, dto) {
        const post = await this.ensurePostExists(postId);
        const reason = dto.reason?.trim();
        if (!reason) {
            throw new common_1.BadRequestException('reason is required');
        }
        if (post.author_id === userId) {
            throw new common_1.BadRequestException('Cannot report your own post');
        }
        try {
            const report = this.socialPostReportRepo.create({
                post_id: postId,
                reporter_id: userId,
                author_id: post.author_id,
                reason,
            });
            await this.socialPostReportRepo.save(report);
        }
        catch (error) {
            const pgError = error;
            if (pgError.code === '23505') {
                throw new common_1.ConflictException('Post already reported by this user');
            }
            throw new common_1.ConflictException('Unable to report post');
        }
        return {
            post_id: postId,
            reported: true,
        };
    }
    async ensurePostExists(postId) {
        const post = await this.socialPostRepo.findOne({ where: { id: postId } });
        if (!post) {
            throw new common_1.NotFoundException('Post not found');
        }
        return post;
    }
    async loadInteractions(userId, postIds) {
        if (postIds.length == 0) {
            return {
                likesCountByPost: new Map(),
                likedByMePostIds: new Set(),
                commentsByPost: new Map(),
            };
        }
        const likesRaw = await this.socialPostLikeRepo
            .createQueryBuilder('l')
            .select('l.post_id', 'post_id')
            .addSelect('COUNT(*)::int', 'likes_count')
            .where('l.post_id IN (:...postIds)', { postIds })
            .groupBy('l.post_id')
            .getRawMany();
        const myLikes = await this.socialPostLikeRepo
            .createQueryBuilder('l')
            .select('l.post_id', 'post_id')
            .where('l.user_id = :userId', { userId })
            .andWhere('l.post_id IN (:...postIds)', { postIds })
            .getRawMany();
        const comments = await this.socialPostCommentRepo
            .createQueryBuilder('c')
            .leftJoinAndSelect('c.author', 'author')
            .where('c.post_id IN (:...postIds)', { postIds })
            .orderBy('c.created_at', 'DESC')
            .getMany();
        const likesCountByPost = new Map();
        for (const row of likesRaw) {
            likesCountByPost.set(row.post_id, Number(row.likes_count) || 0);
        }
        const postIdSet = new Set(postIds);
        const likedByMePostIds = new Set(myLikes.map((like) => like.post_id).filter((postId) => postIdSet.has(postId)));
        const commentsByPost = new Map();
        for (const comment of comments) {
            const existing = commentsByPost.get(comment.post_id) ?? [];
            existing.push(this.serializeComment(comment));
            commentsByPost.set(comment.post_id, existing);
        }
        return { likesCountByPost, likedByMePostIds, commentsByPost };
    }
    getOrderedPlayers(players) {
        const sideRank = (side) => (side === 'home' ? 0 : 1);
        return [...players].sort((a, b) => sideRank(a.side) - sideRank(b.side));
    }
    computeMatchResult(match, orderedPlayers, userId) {
        const home = orderedPlayers[0];
        const away = orderedPlayers[1];
        const homeSets = (match.sets ?? []).filter((set) => set.winner_id === home?.user_id).length;
        const awaySets = (match.sets ?? []).filter((set) => set.winner_id === away?.user_id).length;
        const setsScore = `${homeSets} - ${awaySets}`;
        let winnerId = null;
        if (homeSets > awaySets) {
            winnerId = home?.user_id ?? null;
        }
        else if (awaySets > homeSets) {
            winnerId = away?.user_id ?? null;
        }
        const resultLabel = !winnerId
            ? 'Match'
            : winnerId === userId
                ? 'Victoire'
                : 'Defaite';
        return { setsScore, resultLabel, winnerId, homeSets, awaySets };
    }
    computeMatchGlobalStats(match) {
        const allLegs = (match.sets ?? []).flatMap((set) => set.legs ?? []);
        const allThrows = allLegs.flatMap((leg) => leg.throws ?? []);
        if (allThrows.length === 0) {
            return { average: null, checkoutRate: null };
        }
        const totalScore = allThrows.reduce((sum, t) => sum + t.score, 0);
        const checkoutAttempts = allThrows
            .map((t) => this.extractDoubleAttemptsFromSegment(t.segment ?? ''))
            .reduce((sum, value) => sum + value, 0);
        const checkoutHits = allThrows.filter((t) => t.is_checkout).length;
        return {
            average: Number((totalScore / allThrows.length).toFixed(2)),
            checkoutRate: checkoutAttempts > 0
                ? Number(((checkoutHits / checkoutAttempts) * 100).toFixed(2))
                : 0,
        };
    }
    extractDoubleAttemptsFromSegment(segment) {
        if (segment.startsWith('CD')) {
            return Number.parseInt(segment.slice(2), 10) || 0;
        }
        if (segment.startsWith('CHECKOUT_D')) {
            return Number.parseInt(segment.replace('CHECKOUT_D', ''), 10) || 0;
        }
        return 0;
    }
    serializePost(post, interactions) {
        return {
            id: post.id,
            match_id: post.match_id,
            mode: post.mode,
            sets_score: post.sets_score,
            result_label: post.result_label,
            description: post.description,
            created_at: post.created_at,
            player_1_name: post.player_1_name,
            player_1_score: post.player_1_score,
            player_2_name: post.player_2_name,
            player_2_score: post.player_2_score,
            winner_user_id: post.winner_user_id,
            match_average: post.match_average,
            match_checkout_rate: post.match_checkout_rate,
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
    serializeComment(comment) {
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
};
exports.SocialService = SocialService;
exports.SocialService = SocialService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(social_post_entity_1.SocialPost)),
    __param(1, (0, typeorm_1.InjectRepository)(social_post_like_entity_1.SocialPostLike)),
    __param(2, (0, typeorm_1.InjectRepository)(social_post_comment_entity_1.SocialPostComment)),
    __param(3, (0, typeorm_1.InjectRepository)(social_post_report_entity_1.SocialPostReport)),
    __param(4, (0, typeorm_1.InjectRepository)(friendship_entity_1.Friendship)),
    __param(5, (0, typeorm_1.InjectRepository)(match_entity_1.Match)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], SocialService);
//# sourceMappingURL=social.service.js.map