import { CreateSocialCommentDto } from './dto/create-social-comment.dto';
import { CreateSocialPostDto } from './dto/create-social-post.dto';
import { SocialService } from './social.service';
export declare class SocialController {
    private readonly socialService;
    constructor(socialService: SocialService);
    feed(req: {
        user: {
            id: string;
        };
    }, limit?: number, offset?: number): Promise<{
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
        comments: {
            id: string;
            message: string;
            created_at: Date;
            author: {
                id: string;
                username: string;
                avatar_url: string | null;
            };
        }[];
        author: {
            id: string;
            username: string;
            avatar_url: string | null;
        };
    }[]>;
    createPost(req: {
        user: {
            id: string;
        };
    }, dto: CreateSocialPostDto): Promise<{
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
        comments: {
            id: string;
            message: string;
            created_at: Date;
            author: {
                id: string;
                username: string;
                avatar_url: string | null;
            };
        }[];
        author: {
            id: string;
            username: string;
            avatar_url: string | null;
        };
    }>;
    likePost(req: {
        user: {
            id: string;
        };
    }, postId: string): Promise<{
        post_id: string;
        likes_count: number;
        liked_by_me: boolean;
    }>;
    unlikePost(req: {
        user: {
            id: string;
        };
    }, postId: string): Promise<{
        post_id: string;
        likes_count: number;
        liked_by_me: boolean;
    }>;
    addComment(req: {
        user: {
            id: string;
        };
    }, postId: string, dto: CreateSocialCommentDto): Promise<{
        post_id: string;
        comments_count: number;
        comment: {
            id: string;
            message: string;
            created_at: Date;
            author: {
                id: string;
                username: string;
                avatar_url: string | null;
            };
        };
    }>;
}
