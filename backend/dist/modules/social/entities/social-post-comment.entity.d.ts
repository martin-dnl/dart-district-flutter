import { User } from '../../users/entities/user.entity';
import { SocialPost } from './social-post.entity';
export declare class SocialPostComment {
    id: string;
    post_id: string;
    author_id: string;
    message: string;
    created_at: Date;
    post: SocialPost;
    author: User;
}
