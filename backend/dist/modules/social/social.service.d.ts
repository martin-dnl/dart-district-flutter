import { Repository } from 'typeorm';
import { Friendship } from '../contacts/entities/friendship.entity';
import { Match } from '../matches/entities/match.entity';
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
export declare class SocialService {
    private readonly socialPostRepo;
    private readonly socialPostLikeRepo;
    private readonly socialPostCommentRepo;
    private readonly friendshipRepo;
    private readonly matchRepo;
    constructor(socialPostRepo: Repository<SocialPost>, socialPostLikeRepo: Repository<SocialPostLike>, socialPostCommentRepo: Repository<SocialPostComment>, friendshipRepo: Repository<Friendship>, matchRepo: Repository<Match>);
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
        likes_count: number;
        comments_count: number;
        liked_by_me: boolean;
        comments: SerializedSocialComment[];
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
        likes_count: number;
        comments_count: number;
        liked_by_me: boolean;
        comments: SerializedSocialComment[];
        author: {
            id: string;
            username: string;
            avatar_url: string | null;
        };
    }[]>;
    likePost(userId: string, postId: string): Promise<{
        post_id: string;
        likes_count: number;
        liked_by_me: boolean;
    }>;
    unlikePost(userId: string, postId: string): Promise<{
        post_id: string;
        likes_count: number;
        liked_by_me: boolean;
    }>;
    addComment(userId: string, postId: string, dto: CreateSocialCommentDto): Promise<{
        post_id: string;
        comments_count: number;
        comment: SerializedSocialComment;
    }>;
    private ensurePostExists;
    private loadInteractions;
    private getOrderedPlayers;
    private computeMatchResult;
    private serializePost;
    private serializeComment;
}
export {};
