import { User } from '../../users/entities/user.entity';
import { SocialPost } from './social-post.entity';
export declare class SocialPostLike {
    id: string;
    post_id: string;
    user_id: string;
    created_at: Date;
    post: SocialPost;
    user: User;
}
