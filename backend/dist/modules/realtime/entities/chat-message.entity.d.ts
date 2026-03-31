import { Match } from '../../matches/entities/match.entity';
import { User } from '../../users/entities/user.entity';
export declare class ChatMessage {
    id: string;
    match_id: string;
    user_id: string;
    content: string;
    created_at: Date;
    match: Match;
    user: User;
}
