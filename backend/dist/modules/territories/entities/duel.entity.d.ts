import { Territory } from '../../territories/entities/territory.entity';
import { User } from '../../users/entities/user.entity';
import { Club } from '../../clubs/entities/club.entity';
import { Match } from '../../matches/entities/match.entity';
export declare class Duel {
    id: string;
    territory_id: string;
    challenger_id: string;
    defender_id: string | null;
    challenger_club: string;
    defender_club: string | null;
    match_id: string | null;
    qr_code_id: string | null;
    status: string;
    expires_at: Date;
    created_at: Date;
    territory: Territory;
    challenger: User;
    defender: User;
    challengerClub: Club;
    defenderClub: Club;
    match: Match;
}
