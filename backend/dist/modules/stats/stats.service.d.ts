import { Repository } from 'typeorm';
import { PlayerStat } from './entities/player-stat.entity';
import { EloHistory } from './entities/elo-history.entity';
import { User } from '../users/entities/user.entity';
export declare class StatsService {
    private readonly statRepo;
    private readonly eloRepo;
    private readonly userRepo;
    constructor(statRepo: Repository<PlayerStat>, eloRepo: Repository<EloHistory>, userRepo: Repository<User>);
    getByUser(userId: string): Promise<PlayerStat>;
    updateAfterMatch(userId: string, matchData: {
        avg: number;
        highCheckout: number;
        count180s: number;
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
    processElo(matchId: string, winnerId: string, loserId: string): Promise<{
        winner: {
            elo: number;
            delta: number;
        };
        loser: {
            elo: number;
            delta: number;
        };
    } | undefined>;
    eloHistory(userId: string, limit?: number): Promise<EloHistory[]>;
    private weightedRate;
}
