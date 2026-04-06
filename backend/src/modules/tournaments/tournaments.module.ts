import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Tournament } from './entities/tournament.entity';
import { TournamentPlayer } from './entities/tournament-player.entity';
import { TournamentPool } from './entities/tournament-pool.entity';
import { TournamentPoolStanding } from './entities/tournament-pool-standing.entity';
import { TournamentBracketMatch } from './entities/tournament-bracket-match.entity';
import { TournamentsService } from './tournaments.service';
import { TournamentsController } from './tournaments.controller';
import { User } from '../users/entities/user.entity';
import { ClubMember } from '../clubs/entities/club-member.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Tournament,
      TournamentPlayer,
      TournamentPool,
      TournamentPoolStanding,
      TournamentBracketMatch,
      User,
      ClubMember,
    ]),
  ],
  controllers: [TournamentsController],
  providers: [TournamentsService],
  exports: [TournamentsService],
})
export class TournamentsModule {}
