import {
  Controller,
  Get,
  Param,
  Query,
  UseGuards,
  Req,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { StatsService } from './stats.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('stats')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('stats')
export class StatsController {
  constructor(private readonly statsService: StatsService) {}

  @Get('me')
  myStats(@Req() req: { user: { id: string } }) {
    return this.statsService.getByUser(req.user.id);
  }

  @Get('me/elo-history')
  myEloHistory(@Req() req: { user: { id: string } }, @Query('limit') limit?: number) {
    return this.statsService.eloHistory(req.user.id, limit);
  }

  @Get(':userId')
  userStats(@Param('userId', ParseUUIDPipe) userId: string) {
    return this.statsService.getByUser(userId);
  }

  @Get(':userId/elo-history')
  userEloHistory(@Param('userId', ParseUUIDPipe) userId: string, @Query('limit') limit?: number) {
    return this.statsService.eloHistory(userId, limit);
  }
}
