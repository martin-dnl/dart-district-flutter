import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Territory } from './entities/territory.entity';
import { TerritoryHistory } from './entities/territory-history.entity';
import { Duel } from './entities/duel.entity';
import { TerritoryTileset } from './entities/territory-tileset.entity';
import { TerritoriesService } from './territories.service';
import { TerritoriesController } from './territories.controller';
import { ClubMember } from '../clubs/entities/club-member.entity';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Territory, TerritoryHistory, Duel, TerritoryTileset, ClubMember]),
    RealtimeModule,
  ],
  controllers: [TerritoriesController],
  providers: [TerritoriesService],
  exports: [TerritoriesService],
})
export class TerritoriesModule {}
