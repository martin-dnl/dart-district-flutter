import { AuthProvider } from '../../auth/entities/auth-provider.entity';
import { PlayerStat } from '../../stats/entities/player-stat.entity';
import { ClubMember } from '../../clubs/entities/club-member.entity';
import { UserBadge } from '../../badges/entities/user-badge.entity';
export declare class User {
    id: string;
    username: string;
    email: string | null;
    password_hash: string | null;
    avatar_url: string | null;
    elo: number;
    is_guest: boolean;
    is_active: boolean;
    has_tournament_abandon: boolean;
    is_admin: boolean;
    preferred_hand: string;
    level: string;
    city: string | null;
    region: string | null;
    created_at: Date;
    updated_at: Date;
    auth_providers: AuthProvider[];
    stats: PlayerStat;
    club_memberships: ClubMember[];
    user_badges: UserBadge[];
}
