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
        author: {
            id: string;
            username: string;
            avatar_url: string | null;
        };
    }>;
}
