import { StatsService } from './stats.service';
export declare class StatsController {
    private readonly statsService;
    constructor(statsService: StatsService);
    myStats(req: {
        user: {
            id: string;
        };
    }): Promise<import("./entities/player-stat.entity").PlayerStat>;
    myEloHistory(req: {
        user: {
            id: string;
        };
    }, limit?: number): Promise<import("./entities/elo-history.entity").EloHistory[]>;
    userStats(userId: string): Promise<import("./entities/player-stat.entity").PlayerStat>;
    userEloHistory(userId: string, limit?: number): Promise<import("./entities/elo-history.entity").EloHistory[]>;
}
