import { User } from '../../users/entities/user.entity';
import { SocialPost } from './social-post.entity';
export declare class SocialPostReport {
    id: string;
    post_id: string;
    reporter_id: string;
    author_id: string;
    reason: string;
    created_at: Date;
    post: SocialPost;
    reporter: User;
    author: User;
}
