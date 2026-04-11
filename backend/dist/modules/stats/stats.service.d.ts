import { Repository } from 'typeorm';
import { PlayerStat } from './entities/player-stat.entity';
import { EloHistory } from './entities/elo-history.entity';
import { User } from '../users/entities/user.entity';
import { Throw } from '../matches/entities/throw.entity';
import { Match } from '../matches/entities/match.entity';
import { ClubMember } from '../clubs/entities/club-member.entity';
import { ClubTerritoryPoints } from '../clubs/entities/club-territory-points.entity';
import { Territory } from '../territories/entities/territory.entity';
export declare class StatsService {
    private readonly statRepo;
    private readonly eloRepo;
    private readonly userRepo;
    private readonly throwRepo;
    private readonly matchRepo;
    private readonly clubMemberRepo;
    private readonly ctpRepo;
    private readonly territoryRepo;
    constructor(statRepo: Repository<PlayerStat>, eloRepo: Repository<EloHistory>, userRepo: Repository<User>, throwRepo: Repository<Throw>, matchRepo: Repository<Match>, clubMemberRepo: Repository<ClubMember>, ctpRepo: Repository<ClubTerritoryPoints>, territoryRepo: Repository<Territory>);
    private readonly territoryControlMinPoints;
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
        bestLegDarts?: number;
        won: boolean;
        matchEndedAt?: Date;
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
    eloHistoryByPeriod(userId: string, mode?: 'week' | 'month' | 'year', offset?: number): Promise<{
        mode: "year";
        offset: number;
        period_label: string;
        points: {
            date: string;
            elo: number;
        }[];
    } | {
        mode: "week" | "month";
        offset: number;
        period_label: string;
        points: {
            date: string;
            elo: number;
        }[];
    }>;
    processTerritoryPoints(params: {
        matchId: string;
        winnerId: string;
        loserId: string;
        eloDelta?: number;
    }): Promise<ClubTerritoryPoints | null>;
    private recalculateTerritoryControl;
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
