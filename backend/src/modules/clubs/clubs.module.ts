import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Club } from './entities/club.entity';
import { ClubMember } from './entities/club-member.entity';
import { ClubTerritoryPoints } from './entities/club-territory-points.entity';
import { ClubsService } from './clubs.service';
import { ClubsController } from './clubs.controller';
import { TerritoriesModule } from '../territories/territories.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Club, ClubMember, ClubTerritoryPoints]),
    TerritoriesModule,
  ],
  controllers: [ClubsController],
  providers: [ClubsService],
  exports: [ClubsService],
})
export class ClubsModule {}
