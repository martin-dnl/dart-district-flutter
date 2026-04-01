import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  Req,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { TournamentsService } from './tournaments.service';
import { CreateTournamentDto } from './dto/create-tournament.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { DisqualifyPlayerDto } from './dto/disqualify-player.dto';

@ApiTags('tournaments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('tournaments')
export class TournamentsController {
  constructor(private readonly tournamentsService: TournamentsService) {}

  @Post()
  create(@Body() dto: CreateTournamentDto, @Req() req: { user: { id: string } }) {
    return this.tournamentsService.create(dto, req.user.id);
  }

  @Get()
  findAll(
    @Query('status') status?: string,
    @Query('upcoming') upcoming?: string,
  ) {
    return this.tournamentsService.findAll({ status, upcoming });
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.tournamentsService.findById(id);
  }

  @Post(':id/register')
  register(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: { user: { id: string } },
  ) {
    return this.tournamentsService.registerPlayer(id, req.user.id);
  }

  @Delete(':id/register')
  unregister(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: { user: { id: string } },
  ) {
    return this.tournamentsService.unregisterPlayer(id, req.user.id);
  }

  @Post(':id/pools')
  generatePools(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: { user: { id: string } },
  ) {
    return this.tournamentsService.generatePools(id, req.user.id);
  }

  @Get(':id/pools')
  getPools(@Param('id', ParseUUIDPipe) id: string) {
    return this.tournamentsService.getPools(id);
  }

  @Get(':id/pools/:poolId/standings')
  getPoolStandings(@Param('poolId', ParseUUIDPipe) poolId: string) {
    return this.tournamentsService.getPoolStandings(poolId);
  }

  @Post(':id/bracket')
  generateBracket(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: { user: { id: string } },
  ) {
    return this.tournamentsService.generateBracket(id, req.user.id);
  }

  @Get(':id/bracket')
  getBracket(@Param('id', ParseUUIDPipe) id: string) {
    return this.tournamentsService.getBracket(id);
  }

  @Post(':id/advance')
  advancePhase(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: { user: { id: string } },
  ) {
    return this.tournamentsService.advancePhase(id, req.user.id);
  }

  @Post(':id/disqualify/:playerId')
  disqualify(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('playerId', ParseUUIDPipe) playerId: string,
    @Body() dto: DisqualifyPlayerDto,
    @Req() req: { user: { id: string } },
  ) {
    return this.tournamentsService.disqualifyPlayer(
      id,
      playerId,
      dto.reason,
      req.user.id,
    );
  }
}
