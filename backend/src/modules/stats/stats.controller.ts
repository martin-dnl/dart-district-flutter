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
  myEloHistory(
    @Req() req: { user: { id: string } },
    @Query('limit') limit?: number,
    @Query('mode') mode?: 'week' | 'month' | 'year',
    @Query('offset') offset?: number,
  ) {
    if (mode) {
      return this.statsService.eloHistoryByPeriod(req.user.id, mode, offset);
    }
    return this.statsService.eloHistory(req.user.id, limit);
  }

  @Get('me/dartboard-periods')
  myDartboardPeriods(@Req() req: { user: { id: string } }) {
    return this.statsService.getDartboardPeriods(req.user.id);
  }

  @Get('me/dartboard-heatmap')
  myDartboardHeatmap(
    @Req() req: { user: { id: string } },
    @Query('period') period?: string,
    @Query('year') year?: number,
    @Query('month') month?: number,
  ) {
    return this.statsService.getDartboardHeatmap(req.user.id, {
      period,
      year,
      month,
    });
  }

  @Get(':userId')
  userStats(@Param('userId', ParseUUIDPipe) userId: string) {
    return this.statsService.getByUser(userId);
  }

  @Get(':userId/elo-history')
  userEloHistory(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Query('limit') limit?: number,
    @Query('mode') mode?: 'week' | 'month' | 'year',
    @Query('offset') offset?: number,
  ) {
    if (mode) {
      return this.statsService.eloHistoryByPeriod(userId, mode, offset);
    }
    return this.statsService.eloHistory(userId, limit);
  }

  @Get(':userId/dartboard-periods')
  userDartboardPeriods(@Param('userId', ParseUUIDPipe) userId: string) {
    return this.statsService.getDartboardPeriods(userId);
  }

  @Get(':userId/dartboard-heatmap')
  userDartboardHeatmap(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Query('period') period?: string,
    @Query('year') year?: number,
    @Query('month') month?: number,
  ) {
    return this.statsService.getDartboardHeatmap(userId, {
      period,
      year,
      month,
    });
  }
}
