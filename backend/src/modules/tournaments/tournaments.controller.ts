import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Body,
  UseGuards,
  Req,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { TournamentsService } from './tournaments.service';
import { CreateTournamentDto } from './dto/create-tournament.dto';
import { RegisterClubDto } from './dto/register-club.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('tournaments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('tournaments')
export class TournamentsController {
  constructor(private readonly tournamentsService: TournamentsService) {}

  @Post()
  create(@Body() dto: CreateTournamentDto, @Req() req: { user: { id: string } }) {
    return this.tournamentsService.create(dto as any, req.user.id);
  }

  @Get()
  findAll() {
    return this.tournamentsService.findAll();
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.tournamentsService.findById(id);
  }

  @Post(':id/register')
  register(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RegisterClubDto,
    @Req() req: { user: { id: string } },
  ) {
    return this.tournamentsService.registerClub(id, dto.club_id, req.user.id);
  }

  @Delete(':id/register/:clubId')
  unregister(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('clubId', ParseUUIDPipe) clubId: string,
  ) {
    return this.tournamentsService.unregisterClub(id, clubId);
  }
}
