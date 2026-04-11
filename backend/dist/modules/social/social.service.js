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
const social_post_entity_1 = require("./entities/social-post.entity");
let SocialService = class SocialService {
    constructor(socialPostRepo, friendshipRepo, matchRepo) {
        this.socialPostRepo = socialPostRepo;
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
            relations: ['players', 'players.user', 'sets'],
        });
        if (!match) {
            throw new common_1.NotFoundException('Match not found');
        }
        const orderedPlayers = this.getOrderedPlayers(match.players ?? []);
        const author = orderedPlayers.find((player) => player.user_id === userId);
        if (!author) {
            throw new common_1.BadRequestException('You are not a player in this match');
        }
        const { setsScore, resultLabel } = this.computeMatchResult(match, orderedPlayers, userId);
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
        return posts.map((post) => this.serializePost(post));
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
        return { setsScore, resultLabel };
    }
    serializePost(post) {
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
};
exports.SocialService = SocialService;
exports.SocialService = SocialService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(social_post_entity_1.SocialPost)),
    __param(1, (0, typeorm_1.InjectRepository)(friendship_entity_1.Friendship)),
    __param(2, (0, typeorm_1.InjectRepository)(match_entity_1.Match)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], SocialService);
//# sourceMappingURL=social.service.js.map