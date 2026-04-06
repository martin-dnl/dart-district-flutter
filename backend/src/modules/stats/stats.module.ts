import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PlayerStat } from './entities/player-stat.entity';
import { EloHistory } from './entities/elo-history.entity';
import { User } from '../users/entities/user.entity';
import { StatsService } from './stats.service';
import { StatsController } from './stats.controller';
import { Throw } from '../matches/entities/throw.entity';
import { Match } from '../matches/entities/match.entity';
import { ClubMember } from '../clubs/entities/club-member.entity';
import { ClubTerritoryPoints } from '../clubs/entities/club-territory-points.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      PlayerStat,
      EloHistory,
      User,
      Throw,
      Match,
      ClubMember,
      ClubTerritoryPoints,
    ]),
  ],
  controllers: [StatsController],
  providers: [StatsService],
  exports: [StatsService],
})
export class StatsModule {}
