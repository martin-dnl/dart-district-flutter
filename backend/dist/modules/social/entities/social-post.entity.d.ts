import { User } from '../../users/entities/user.entity';
export declare class SocialPost {
    id: string;
    author_id: string;
    match_id: string;
    mode: string;
    sets_score: string;
    result_label: string;
    description: string | null;
    created_at: Date;
    author: User;
}
