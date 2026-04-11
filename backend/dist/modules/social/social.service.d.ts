import { Repository } from 'typeorm';
import { Friendship } from '../contacts/entities/friendship.entity';
import { Match } from '../matches/entities/match.entity';
import { SocialPost } from './entities/social-post.entity';
export declare class SocialService {
    private readonly socialPostRepo;
    private readonly friendshipRepo;
    private readonly matchRepo;
    constructor(socialPostRepo: Repository<SocialPost>, friendshipRepo: Repository<Friendship>, matchRepo: Repository<Match>);
    createPost(userId: string, body: {
        match_id: string;
        description?: string;
    }): Promise<{
        id: string;
        match_id: string;
        mode: string;
        sets_score: string;
        result_label: string;
        description: string | null;
        created_at: Date;
        author: {
            id: string;
            username: string;
            avatar_url: string | null;
        };
    }>;
    listFeed(userId: string, limit?: number, offset?: number): Promise<{
        id: string;
        match_id: string;
        mode: string;
        sets_score: string;
        result_label: string;
        description: string | null;
        created_at: Date;
        author: {
            id: string;
            username: string;
            avatar_url: string | null;
        };
    }[]>;
    private getOrderedPlayers;
    private computeMatchResult;
    private serializePost;
}
