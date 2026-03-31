import { Repository } from 'typeorm';
import { Tournament } from './entities/tournament.entity';
import { TournamentRegistration } from './entities/tournament-registration.entity';
export declare class TournamentsService {
    private readonly tournamentRepo;
    private readonly regRepo;
    constructor(tournamentRepo: Repository<Tournament>, regRepo: Repository<TournamentRegistration>);
    create(dto: Partial<Tournament>, userId: string): Promise<Tournament>;
    findAll(): Promise<Tournament[]>;
    findById(id: string): Promise<{
        registrations: TournamentRegistration[];
        id: string;
        name: string;
        description: string | null;
        territory_id: string | null;
        is_territorial: boolean;
        mode: string;
        finish: string;
        venue_name: string | null;
        venue_address: string | null;
        city: string | null;
        entry_fee: number;
        max_clubs: number;
        enrolled_clubs: number;
        status: string;
        scheduled_at: Date;
        ended_at: Date | null;
        created_by: string | null;
        created_at: Date;
        territory: import("../territories/entities/territory.entity").Territory;
        creator: import("../users/entities/user.entity").User;
    }>;
    registerClub(tournamentId: string, clubId: string, userId: string): Promise<TournamentRegistration>;
    unregisterClub(tournamentId: string, clubId: string): Promise<void>;
}
