import { Tournament } from './tournament.entity';
import { Club } from '../../clubs/entities/club.entity';
import { User } from '../../users/entities/user.entity';
export declare class TournamentRegistration {
    id: string;
    tournament_id: string;
    club_id: string;
    registered_by: string;
    registered_at: Date;
    tournament: Tournament;
    club: Club;
    registrant: User;
}
