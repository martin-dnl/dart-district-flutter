import { Repository } from 'typeorm';
import { PlayerStat } from './entities/player-stat.entity';
import { EloHistory } from './entities/elo-history.entity';
import { User } from '../users/entities/user.entity';
import { Throw } from '../matches/entities/throw.entity';
export declare class StatsService {
    private readonly statRepo;
    private readonly eloRepo;
    private readonly userRepo;
    private readonly throwRepo;
    constructor(statRepo: Repository<PlayerStat>, eloRepo: Repository<EloHistory>, userRepo: Repository<User>, throwRepo: Repository<Throw>);
    getByUser(userId: string): Promise<PlayerStat>;
    updateAfterMatch(userId: string, matchData: {
        avg: number;
        highCheckout: number;
        count180s: number;
        count140Plus: number;
        count100Plus: number;
        checkoutHits: number;
        checkoutAttempts: number;
        t20Hits: number;
        t20Attempts: number;
        t19Hits: number;
        t19Attempts: number;
        doubleHits: number;
        doubleAttempts: number;
        won: boolean;
    }): Promise<PlayerStat | undefined>;
    processElo(matchId: string, winnerId: string, loserId: string, isRanked?: boolean): Promise<{
        winner: {
            elo: number;
            delta: number;
        };
        loser: {
            elo: number;
            delta: number;
        };
    } | null | undefined>;
    eloHistory(userId: string, limit?: number): Promise<EloHistory[]>;
    getDartboardPeriods(userId: string): Promise<{
        years: {
            year: number;
            months: number[];
        }[];
    }>;
    getDartboardHeatmap(userId: string, filter: {
        period?: string;
        year?: number;
        month?: number;
    }): Promise<{
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
    private normalizePeriod;
    private weightedRate;
}
