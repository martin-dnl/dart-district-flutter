import { TournamentsService } from './tournaments.service';
import { CreateTournamentDto } from './dto/create-tournament.dto';
import { RegisterClubDto } from './dto/register-club.dto';
export declare class TournamentsController {
    private readonly tournamentsService;
    constructor(tournamentsService: TournamentsService);
    create(dto: CreateTournamentDto, req: {
        user: {
            id: string;
        };
    }): Promise<import("./entities/tournament.entity").Tournament>;
    findAll(): Promise<import("./entities/tournament.entity").Tournament[]>;
    findOne(id: string): Promise<{
        registrations: import("./entities/tournament-registration.entity").TournamentRegistration[];
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
    register(id: string, dto: RegisterClubDto, req: {
        user: {
            id: string;
        };
    }): Promise<import("./entities/tournament-registration.entity").TournamentRegistration>;
    unregister(id: string, clubId: string): Promise<void>;
}
