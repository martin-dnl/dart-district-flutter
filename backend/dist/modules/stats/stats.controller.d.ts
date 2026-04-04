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
    myDartboardPeriods(req: {
        user: {
            id: string;
        };
    }): Promise<{
        years: {
            year: number;
            months: number[];
        }[];
    }>;
    myDartboardHeatmap(req: {
        user: {
            id: string;
        };
    }, period?: string, year?: number, month?: number): Promise<{
        period: string;
        year: number | null;
        month: number | null;
        total_throws: number;
        total_hits: number;
        hits: {
            x: number;
            y: number;
            score: number;
            label: string | undefined;
            played_at: Date;
        }[];
    }>;
    userStats(userId: string): Promise<import("./entities/player-stat.entity").PlayerStat>;
    userEloHistory(userId: string, limit?: number): Promise<import("./entities/elo-history.entity").EloHistory[]>;
    userDartboardPeriods(userId: string): Promise<{
        years: {
            year: number;
            months: number[];
        }[];
    }>;
    userDartboardHeatmap(userId: string, period?: string, year?: number, month?: number): Promise<{
        period: string;
        year: number | null;
        month: number | null;
        total_throws: number;
        total_hits: number;
        hits: {
            x: number;
            y: number;
            score: number;
            label: string | undefined;
            played_at: Date;
        }[];
    }>;
}
