import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Body,
  UseGuards,
  Req,
  Query,
  BadRequestException,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { TerritoriesService } from './territories.service';
import { CreateDuelDto } from './dto/create-duel.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { QueryTerritoryStatusesDto } from './dto/query-territory-statuses.dto';
import { UpdateTerritoryStatusDto } from './dto/update-territory-status.dto';
import { UpdateTerritoryOwnerDto } from './dto/update-territory-owner.dto';

@ApiTags('territories')
@Controller('territories')
export class TerritoriesController {
  constructor(private readonly territoriesService: TerritoriesService) {}

  @Get('tileset')
  tilesetMetadata() {
    return this.territoriesService.getTilesetMetadata();
  }

  @Get('tileset/active-zones')
  async activeZones() {
    const codes = await this.territoriesService.getActiveIrisCodes();
    return {
      success: true,
      data: {
        codes,
      },
      error: null,
    };
  }

  @Get('map/statuses')
  mapStatuses(@Query() query: QueryTerritoryStatusesDto) {
    return this.territoriesService.getMapStatuses(query);
  }

  @Get('map/data')
  getMapData() {
    return this.territoriesService.getMapData();
  }

  @Get('clubs/zones')
  getClubZones() {
    return this.territoriesService.getClubZones();
  }

  @Get('map/hit')
  mapHit(
    @Query('lat') latRaw: string,
    @Query('lng') lngRaw: string,
    @Query('zoom') zoomRaw?: string,
    @Query('viewport_width_px') viewportWidthRaw?: string,
    @Query('active_only') activeOnlyRaw?: string,
  ) {
    const lat = Number.parseFloat(latRaw);
    const lng = Number.parseFloat(lngRaw);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      throw new BadRequestException('lat and lng query params are required numbers');
    }

    const zoom = zoomRaw == null ? undefined : Number.parseFloat(zoomRaw);
    const viewportWidthPx =
      viewportWidthRaw == null ? undefined : Number.parseFloat(viewportWidthRaw);

    if (zoomRaw != null && !Number.isFinite(zoom)) {
      throw new BadRequestException('zoom query param must be a valid number');
    }

    if (viewportWidthRaw != null && !Number.isFinite(viewportWidthPx)) {
      throw new BadRequestException(
        'viewport_width_px query param must be a valid number',
      );
    }

    const activeOnly =
      activeOnlyRaw == null
        ? true
        : !['0', 'false', 'no', 'off'].includes(activeOnlyRaw.toLowerCase());

    const hit = this.territoriesService.hitTestByCoordinates(
      lat,
      lng,
      zoom,
      viewportWidthPx,
    );

    if (!activeOnly) {
      return hit;
    }

    return hit.then(async (result) => {
      const code = (result?.code_iris ?? '').toString().trim().toUpperCase();
      if (!code) {
        return { code_iris: null };
      }

      const activeCodes = await this.territoriesService.getActiveIrisCodes();
      if (!activeCodes.includes(code)) {
        return { code_iris: null };
      }

      return result;
    });
  }

  @Get()
  findAll() {
    return this.territoriesService.findAll();
  }

  @Get(':codeIris')
  findOne(@Param('codeIris') codeIris: string) {
    return this.territoriesService.findByCodeIris(codeIris);
  }

  @Get(':codeIris/panel')
  panel(@Param('codeIris') codeIris: string) {
    return this.territoriesService.getTerritoryPanel(codeIris);
  }

  @Get(':codeIris/history')
  history(@Param('codeIris') codeIris: string) {
    return this.territoriesService.history(codeIris);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Patch(':codeIris/status')
  updateStatus(
    @Param('codeIris') codeIris: string,
    @Body() dto: UpdateTerritoryStatusDto,
    @Req() req: { user: { id: string } },
  ) {
    return this.territoriesService.updateStatus(codeIris, dto, req.user.id);
  }

  @Patch(':codeIris/owner')
  updateOwner(
    @Param('codeIris') codeIris: string,
    @Body() dto: UpdateTerritoryOwnerDto,
  ) {
    return this.territoriesService.transferOwnership(
      codeIris,
      dto.winner_club_id ?? dto.owner_club_id ?? null,
      dto.event ?? 'manual_transfer',
    );
  }

  /* ── Duels ── */

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Post('duels')
  createDuel(@Body() dto: CreateDuelDto, @Req() req: { user: { id: string } }) {
    return this.territoriesService.createDuel(dto, req.user.id);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Get('duels/pending')
  pendingDuels(@Req() req: { user: { id: string } }) {
    return this.territoriesService.findPendingDuelsForUser(req.user.id);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Patch('duels/:id/accept')
  acceptDuel(@Param('id') id: string) {
    return this.territoriesService.acceptDuel(id);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Patch('duels/:id/complete')
  completeDuel(
    @Param('id') id: string,
    @Body('winner_club_id') winnerClubId: string,
  ) {
    return this.territoriesService.completeDuel(id, winnerClubId);
  }
}
