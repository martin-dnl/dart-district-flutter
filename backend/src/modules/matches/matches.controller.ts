import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Body,
  Query,
  UseGuards,
  Req,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { MatchesService } from './matches.service';
import { CreateMatchDto } from './dto/create-match.dto';
import { SubmitThrowDto } from './dto/submit-throw.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('matches')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('matches')
export class MatchesController {
  constructor(private readonly matchesService: MatchesService) {}

  @Post('invitation')
  createInvitation(
    @Body()
    body: {
      invitee_id: string;
      mode: string;
      starting_score?: number;
      player_names?: string[];
      sets_to_win?: number;
      legs_per_set?: number;
      finish_type?: string;
    },
    @Req() req: { user: { id: string } },
  ) {
    return this.matchesService.createInvitation(req.user.id, body);
  }

  @Get('ongoing')
  ongoing(@Req() req: { user: { id: string } }) {
    return this.matchesService.getOngoingForUser(req.user.id);
  }

  @Post(':id/accept')
  acceptInvitation(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: { user: { id: string } },
  ) {
    return this.matchesService.acceptInvitation(id, req.user.id);
  }

  @Post(':id/refuse')
  refuseInvitation(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: { user: { id: string } },
  ) {
    return this.matchesService.refuseInvitation(id, req.user.id);
  }

  @Post(':id/cancel')
  cancelInvitation(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: { user: { id: string } },
  ) {
    return this.matchesService.cancelInvitation(id, req.user.id);
  }

  @Post(':id/score')
  submitScore(
    @Param('id', ParseUUIDPipe) id: string,
    @Body()
    body: {
      player_index: number;
      score: number;
      doubles_attempted?: number;
      dart_positions?: Array<{
        x: number;
        y: number;
        score?: number;
        label?: string;
      }>;
    },
    @Req() req: { user: { id: string } },
  ) {
    return this.matchesService.submitScore(id, req.user.id, body);
  }

  @Post(':id/undo')
  undoLastThrow(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: { user: { id: string } },
  ) {
    return this.matchesService.undoLastThrow(id, req.user.id);
  }

  @Post(':id/abandon')
  abandonMatch(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: { surrendered_by_index: number },
    @Req() req: { user: { id: string } },
  ) {
    return this.matchesService.abandonMatch(id, req.user.id, body);
  }

  @Post()
  create(@Body() dto: CreateMatchDto) {
    return this.matchesService.create(dto);
  }

  @Get('me')
  myMatches(
    @Req() req: { user: { id: string } },
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
    @Query('status') status?: string,
    @Query('ranked') ranked?: string,
  ) {
    return this.matchesService.findByUser(
      req.user.id,
      limit,
      offset,
      status,
      ranked,
    );
  }

  @Get(':id/report')
  report(@Param('id', ParseUUIDPipe) id: string) {
    return this.matchesService.getMatchReport(id);
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.matchesService.findById(id);
  }

  @Post(':id/legs/:legId/throws')
  submitThrow(
    @Param('id', ParseUUIDPipe) matchId: string,
    @Param('legId', ParseUUIDPipe) legId: string,
    @Body() dto: SubmitThrowDto,
    @Req() req: { user: { id: string } },
  ) {
    return this.matchesService.submitThrow(matchId, legId, req.user.id, dto);
  }

  @Patch(':id/validate')
  validate(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: { user: { id: string } },
  ) {
    return this.matchesService.validateMatch(id, req.user.id);
  }
}
