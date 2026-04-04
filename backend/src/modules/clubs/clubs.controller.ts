import {
  ForbiddenException,
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  Req,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { ClubsService } from './clubs.service';
import { CreateClubDto } from './dto/create-club.dto';
import { UpdateClubDto } from './dto/update-club.dto';
import { ManageMemberDto } from './dto/manage-member.dto';
import { ResolveTerritoryDto } from './dto/resolve-territory.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TerritoriesService } from '../territories/territories.service';

@ApiTags('clubs')
@Controller('clubs')
export class ClubsController {
  constructor(
    private readonly clubsService: ClubsService,
    private readonly territoriesService: TerritoriesService,
  ) {}

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Post('resolve-territory')
  async resolveTerritory(@Body() dto: ResolveTerritoryDto) {
    // Resolve from source polygons first (exact hit + tolerant nearest fallback).
    const polygonCodeIris = await this.territoriesService.resolveCodeIrisByPolygon(
      dto.latitude,
      dto.longitude,
    );

    let codeIris = (polygonCodeIris ?? '').toString().trim().toUpperCase();
    if (!codeIris) {
      // Fallback to nearest centroid with a broader threshold.
      codeIris =
        (await this.clubsService.resolveNearestCodeIris(
          dto.latitude,
          dto.longitude,
          30,
        )) ??
        '';
    }

    if (!codeIris) {
      return {
        success: false,
        data: null,
        error: 'no_territory_found',
      };
    }

    const territory = await this.territoriesService.findByCodeIris(codeIris);
    return {
      success: true,
      data: {
        code_iris: territory.code_iris,
        name: territory.name,
        city: territory.nom_com,
        department: territory.dep_name,
        region: territory.region_name,
        latitude: territory.centroid_lat,
        longitude: territory.centroid_lng,
      },
      error: null,
    };
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Post()
  create(
    @Body() dto: CreateClubDto,
    @Req() req: { user: { id: string; is_guest?: boolean } },
  ) {
    if (req.user.is_guest || req.user.id === 'guest') {
      throw new ForbiddenException('Guest account cannot create a club');
    }

    return this.clubsService.create(dto, req.user.id);
  }

  @Get()
  findAll(
    @Query('limit') limit?: number,
    @Query('q') q?: string,
    @Query('city') city?: string,
  ) {
    return this.clubsService.findAll(limit, q, city);
  }

  @Get('search')
  search(
    @Query('q') q?: string,
    @Query('lat') lat?: number,
    @Query('lng') lng?: number,
    @Query('radius') radius?: number,
    @Query('limit') limit?: number,
  ) {
    return this.clubsService.search({ q, lat, lng, radius, limit });
  }

  @Get('ranking')
  ranking(@Query('limit') limit?: number) {
    return this.clubsService.ranking(limit);
  }

  @Get('map')
  mapClubs() {
    return this.clubsService.findForMap();
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.clubsService.findById(id);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateClubDto,
    @Req() req: { user: { id: string; is_guest?: boolean } },
  ) {
    if (req.user.is_guest || req.user.id === 'guest') {
      throw new ForbiddenException('Guest account cannot update a club');
    }

    return this.clubsService.update(id, dto, req.user.id);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Post(':id/members')
  addMember(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ManageMemberDto,
    @Req() req: { user: { id: string; is_guest?: boolean } },
  ) {
    if (req.user.is_guest || req.user.id === 'guest') {
      throw new ForbiddenException('Guest account cannot join a club');
    }

    return this.clubsService.addMember(id, dto.user_id, dto.role);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Patch(':id/members/:userId/role')
  updateRole(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body() dto: ManageMemberDto,
    @Req() req: { user: { id: string } },
  ) {
    return this.clubsService.updateMemberRole(id, userId, dto.role!, req.user.id);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Delete(':id/members/:userId')
  removeMember(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Req() req: { user: { id: string } },
  ) {
    return this.clubsService.removeMember(id, userId, req.user.id);
  }
}
