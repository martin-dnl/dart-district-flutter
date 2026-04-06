import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Match } from './entities/match.entity';
import { MatchPlayer } from './entities/match-player.entity';
import { Set } from './entities/set.entity';
import { Leg } from './entities/leg.entity';
import { Throw } from './entities/throw.entity';
import { MatchesService } from './matches.service';
import { MatchesController } from './matches.controller';
import { RealtimeModule } from '../realtime/realtime.module';
import { StatsModule } from '../stats/stats.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Match, MatchPlayer, Set, Leg, Throw]),
    RealtimeModule,
    StatsModule,
  ],
  controllers: [MatchesController],
  providers: [MatchesService],
  exports: [MatchesService],
})
export class MatchesModule {}
