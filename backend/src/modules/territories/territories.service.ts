import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { readFile } from 'fs/promises';
import * as path from 'path';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, QueryFailedError, Repository } from 'typeorm';
import { Territory } from './entities/territory.entity';
import { TerritoryHistory } from './entities/territory-history.entity';
import { Duel } from './entities/duel.entity';
import { CreateDuelDto } from './dto/create-duel.dto';
import { QueryTerritoryStatusesDto } from './dto/query-territory-statuses.dto';
import { UpdateTerritoryStatusDto } from './dto/update-territory-status.dto';
import { TerritoryGateway } from '../realtime/gateways/territory.gateway';
import { ClubMember } from '../clubs/entities/club-member.entity';
import { TerritoryTileset } from './entities/territory-tileset.entity';

type Ring = Array<[number, number]>;
type PolygonRings = Ring[];
type MultiPolygonRings = PolygonRings[];

type IndexedIrisFeature = {
  codeIris: string;
  minLng: number;
  minLat: number;
  maxLng: number;
  maxLat: number;
  polygons: MultiPolygonRings;
};

@Injectable()
export class TerritoriesService {
  private static readonly HIT_TEST_MAX_VISIBLE_WIDTH_KM = 5;
  private schemaInfoPromise?: Promise<{
    hasIrisTerritories: boolean;
    hasLegacyTerritories: boolean;
    hasTilesetTable: boolean;
  }>;
  private irisGeoIndexPromise?: Promise<IndexedIrisFeature[]>;

  constructor(
    @InjectRepository(Territory) private readonly territoryRepo: Repository<Territory>,
    @InjectRepository(TerritoryHistory) private readonly historyRepo: Repository<TerritoryHistory>,
    @InjectRepository(Duel) private readonly duelRepo: Repository<Duel>,
    @InjectRepository(ClubMember) private readonly clubMemberRepo: Repository<ClubMember>,
    @InjectRepository(TerritoryTileset) private readonly tilesetRepo: Repository<TerritoryTileset>,
    private readonly territoryGateway: TerritoryGateway,
    private readonly dataSource: DataSource,
  ) {}

  private resolveTilesetSourceUrl(sourceUrl: string) {
    const explicitOverride = process.env.IRIS_PMTILES_URL?.trim();
    if (explicitOverride) {
      return explicitOverride;
    }

    if (process.env.NODE_ENV === 'production') {
      return sourceUrl;
    }

    if (!sourceUrl.includes('converted.pmtiles')) {
      return sourceUrl;
    }

    const baseUrl =
      process.env.BACKEND_PUBLIC_BASE_URL?.trim() ||
      `http://localhost:${process.env.BACKEND_PORT ?? process.env.PORT ?? '3000'}`;

    return `${baseUrl.replace(/\/+$/, '')}/tiles/converted.pmtiles`;
  }

  private withResolvedTilesetSourceUrl<T extends { source_url: string }>(tileset: T): T {
    return {
      ...tileset,
      source_url: this.resolveTilesetSourceUrl(tileset.source_url),
    };
  }

  private fallbackTilesetMetadata() {
    return this.withResolvedTilesetSourceUrl({
      key: 'iris_france_pmtiles',
      format: 'pmtiles',
      source_url: process.env.IRIS_PMTILES_URL ?? 'https://dart-district.fr/tiles/converted.pmtiles',
      attribution: 'INSEE + IGN Contours IRIS',
      minzoom: 0,
      maxzoom: 14,
      bounds_west: -5.225,
      bounds_south: 41.333,
      bounds_east: 9.85,
      bounds_north: 51.2,
      center_lng: 2.2137,
      center_lat: 46.2276,
      center_zoom: 6,
      layer_name: 'iris',
      is_active: true,
    });
  }

  private isMissingRelationError(error: unknown, relationName: string): boolean {
    return error instanceof QueryFailedError && error.message.includes(`relation "${relationName}" does not exist`);
  }

  private isMissingColumnError(error: unknown, columnName: string): boolean {
    return error instanceof QueryFailedError && error.message.includes(`column ${columnName} does not exist`);
  }

  private async getSchemaInfo() {
    if (!this.schemaInfoPromise) {
      this.schemaInfoPromise = this.loadSchemaInfo();
    }

    return this.schemaInfoPromise;
  }

  private async loadSchemaInfo() {
    const columns = await this.dataSource.query(
      `
        SELECT table_name, column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name IN ('territories', 'territory_tilesets')
      `,
    );

    const columnSet = new Set<string>(
      columns.map((row: { table_name: string; column_name: string }) => `${row.table_name}.${row.column_name}`),
    );

    return {
      hasIrisTerritories: columnSet.has('territories.code_iris'),
      hasLegacyTerritories:
        columnSet.has('territories.id') &&
        columnSet.has('territories.code') &&
        columnSet.has('territories.latitude') &&
        columnSet.has('territories.longitude'),
      hasTilesetTable: columns.some((row: { table_name: string }) => row.table_name === 'territory_tilesets'),
    };
  }

  private async ensureIrisSchema(feature: string) {
    const schema = await this.getSchemaInfo();
    if (schema.hasIrisTerritories) {
      return;
    }

    throw new ServiceUnavailableException(
      `IRIS territory schema is not applied for ${feature}. Run backend/sql/006_iris_territories_refactor.sql on the database.`,
    );
  }

  private async findAllLegacy() {
    const rows = await this.dataSource.query(
      `
        SELECT
          t.id::text AS id,
          LEFT(t.code, 9) AS code_iris,
          COALESCE(t.name, t.code, 'Territoire') AS name,
          t.status::text AS status,
          t.owner_club_id::text AS owner_club_id,
          c.name AS owner_club_name,
          t.latitude AS centroid_lat,
          t.longitude AS centroid_lng,
          t.created_at,
          COALESCE(t.updated_at, t.created_at) AS updated_at
        FROM territories t
        LEFT JOIN clubs c ON c.id = t.owner_club_id
        ORDER BY t.code ASC
      `,
    );

    return rows.map((row: Record<string, unknown>) => ({
      id: row.id,
      code_iris: row.code_iris,
      name: row.name,
      status: row.status,
      owner_club_id: row.owner_club_id,
      owner_club: row.owner_club_id
        ? {
            id: row.owner_club_id,
            name: row.owner_club_name,
          }
        : null,
      centroid_lat: row.centroid_lat,
      centroid_lng: row.centroid_lng,
      created_at: row.created_at,
      updated_at: row.updated_at,
    }));
  }

  private normalizeCodeIris(code: string): string {
    const normalized = code.trim().toUpperCase();
    if (!/^[0-9A-Z]{9}$/.test(normalized)) {
      throw new BadRequestException('Invalid IRIS code format');
    }
    return normalized;
  }

  private async resolveUserClubId(userId: string): Promise<string> {
    const membership = await this.clubMemberRepo.findOne({
      where: { user_id: userId, is_active: true },
      order: { joined_at: 'ASC' },
    });

    if (!membership) {
      throw new BadRequestException('User has no active club membership');
    }

    return membership.club_id;
  }

  async getTilesetMetadata() {
    const schema = await this.getSchemaInfo();
    if (!schema.hasTilesetTable) {
      return this.fallbackTilesetMetadata();
    }

    let fromDb: TerritoryTileset | null = null;
    try {
      fromDb = await this.tilesetRepo.findOne({
        where: { is_active: true },
        order: { updated_at: 'DESC' },
      });
    } catch (error) {
      if (!this.isMissingRelationError(error, 'territory_tilesets')) {
        throw error;
      }
    }

    if (fromDb) {
      return this.withResolvedTilesetSourceUrl({
        ...fromDb,
      });
    }

    return this.fallbackTilesetMetadata();
  }

  /* ── Territories ── */

  async findAll() {
    const schema = await this.getSchemaInfo();
    if (!schema.hasIrisTerritories && schema.hasLegacyTerritories) {
      return this.findAllLegacy();
    }

    return this.territoryRepo.find({
      relations: ['owner_club'],
      order: { code_iris: 'ASC' },
    });
  }

  async getMapStatuses(query: QueryTerritoryStatusesDto) {
    const schema = await this.getSchemaInfo();
    if (!schema.hasIrisTerritories) {
      return {
        count: 0,
        statuses: [],
        schema_warning:
          'IRIS territory schema is not applied. Run backend/sql/006_iris_territories_refactor.sql.',
      };
    }

    const qb = this.territoryRepo
      .createQueryBuilder('t')
      .select([
        't.code_iris AS code_iris',
        't.status AS status',
        't.owner_club_id AS owner_club_id',
        't.updated_at AS updated_at',
        't.dep_code AS dep_code',
      ]);

    if (query.status) {
      qb.andWhere('t.status = :status', { status: query.status });
    }

    if (query.dep_code) {
      qb.andWhere('t.dep_code = :depCode', { depCode: query.dep_code });
    }

    if (query.updated_since) {
      qb.andWhere('t.updated_at > :updatedSince', { updatedSince: query.updated_since });
    }

    const statuses = await qb.orderBy('t.code_iris', 'ASC').getRawMany();
    return {
      count: statuses.length,
      statuses,
    };
  }

  async getMapData() {
    const schema = await this.getSchemaInfo();
    if (!schema.hasIrisTerritories) {
      return {
        territories: [],
        clubs: [],
        warning:
          'IRIS territory schema is not applied. Run backend/sql/006_iris_territories_refactor.sql.',
      };
    }

    // Get all territories with complete info
    const territories = await this.territoryRepo.find({
      relations: ['owner_club'],
      order: { code_iris: 'ASC' },
    });

    // Get club rankings by number of conquered territories
    const clubRankings = await this.dataSource.query(`
      SELECT 
        c.id,
        c.name,
        COUNT(t.code_iris) as territories_count,
        COUNT(CASE WHEN t.status = 'conquered' THEN 1 END) as conquered_count,
        COUNT(CASE WHEN t.status = 'locked' THEN 1 END) as locked_count,
        COUNT(CASE WHEN t.status = 'alert' THEN 1 END) as alert_count,
        COUNT(CASE WHEN t.status = 'conflict' THEN 1 END) as conflict_count
      FROM clubs c
      LEFT JOIN territories t ON c.id = t.owner_club_id
      GROUP BY c.id, c.name
      ORDER BY conquered_count DESC, territories_count DESC
    `);

    return {
      territories: territories.map((t) => ({
        id: t.code_iris,
        code_iris: t.code_iris,
        name: t.name,
        status: t.status,
        owner_club_id: t.owner_club_id,
        owner_club: t.owner_club
          ? {
              id: t.owner_club.id,
              name: t.owner_club.name,
            }
          : null,
        centroid_lat: t.centroid_lat,
        centroid_lng: t.centroid_lng,
        updated_at: t.updated_at,
      })),
      clubs: clubRankings.map((c: any) => ({
        id: c.id,
        name: c.name,
        territories_count: parseInt(c.territories_count, 10),
        conquered_count: parseInt(c.conquered_count, 10),
        locked_count: parseInt(c.locked_count, 10),
        alert_count: parseInt(c.alert_count, 10),
        conflict_count: parseInt(c.conflict_count, 10),
      })),
    };
  }

  private resolveIrisGeoJsonPath(): string {
    const configured = process.env.IRIS_GEOJSON_PATH?.trim();
    if (configured) {
      return path.isAbsolute(configured)
        ? configured
        : path.resolve(process.cwd(), configured);
    }

    return path.resolve(process.cwd(), '..', 'iris_data', 'iris_france.geojson');
  }

  private async getIrisGeoIndex(): Promise<IndexedIrisFeature[]> {
    if (!this.irisGeoIndexPromise) {
      this.irisGeoIndexPromise = this.loadIrisGeoIndex();
    }
    return this.irisGeoIndexPromise;
  }

  private async loadIrisGeoIndex(): Promise<IndexedIrisFeature[]> {
    const filePath = this.resolveIrisGeoJsonPath();
    const raw = await readFile(filePath, 'utf8');
    const parsed = JSON.parse(raw) as {
      type?: string;
      features?: Array<{
        properties?: Record<string, unknown>;
        geometry?: {
          type?: string;
          coordinates?: unknown;
        };
      }>;
    };

    if (parsed.type !== 'FeatureCollection' || !Array.isArray(parsed.features)) {
      throw new ServiceUnavailableException('IRIS GeoJSON file is invalid or unreadable.');
    }

    const indexed: IndexedIrisFeature[] = [];
    for (const feature of parsed.features) {
      const codeIris = (feature.properties?.code_iris ?? '').toString().trim().toUpperCase();
      if (!/^[0-9A-Z]{9}$/.test(codeIris)) {
        continue;
      }

      const polygons = this.extractPolygons(feature.geometry?.type, feature.geometry?.coordinates);
      if (polygons.length === 0) {
        continue;
      }

      let minLng = Number.POSITIVE_INFINITY;
      let minLat = Number.POSITIVE_INFINITY;
      let maxLng = Number.NEGATIVE_INFINITY;
      let maxLat = Number.NEGATIVE_INFINITY;

      for (const polygon of polygons) {
        for (const ring of polygon) {
          for (const point of ring) {
            const lng = point[0];
            const lat = point[1];
            if (lng < minLng) minLng = lng;
            if (lat < minLat) minLat = lat;
            if (lng > maxLng) maxLng = lng;
            if (lat > maxLat) maxLat = lat;
          }
        }
      }

      indexed.push({
        codeIris,
        minLng,
        minLat,
        maxLng,
        maxLat,
        polygons,
      });
    }

    return indexed;
  }

  private extractPolygons(geometryType?: string, coordinates?: unknown): MultiPolygonRings {
    if (!geometryType || coordinates == null) {
      return [];
    }

    if (geometryType === 'Polygon') {
      const polygon = this.parsePolygon(coordinates);
      return polygon === null ? [] : [polygon];
    }

    if (geometryType === 'MultiPolygon') {
      if (!Array.isArray(coordinates)) {
        return [];
      }
      const result: MultiPolygonRings = [];
      for (const part of coordinates) {
        const polygon = this.parsePolygon(part);
        if (polygon !== null) {
          result.push(polygon);
        }
      }
      return result;
    }

    return [];
  }

  private parsePolygon(rawPolygon: unknown): PolygonRings | null {
    if (!Array.isArray(rawPolygon)) {
      return null;
    }

    const rings: PolygonRings = [];
    for (const rawRing of rawPolygon) {
      if (!Array.isArray(rawRing)) {
        continue;
      }

      const ring: Ring = [];
      for (const rawPoint of rawRing) {
        if (Array.isArray(rawPoint) && rawPoint.length >= 2) {
          const lngRaw = rawPoint[0];
          const latRaw = rawPoint[1];
          if (typeof lngRaw === 'number' && typeof latRaw === 'number') {
            ring.push([lngRaw, latRaw]);
          }
        }
      }

      if (ring.length >= 3) {
        rings.push(ring);
      }
    }

    return rings.length === 0 ? null : rings;
  }

  private isPointInRing(lng: number, lat: number, ring: Ring): boolean {
    let inside = false;
    let j = ring.length - 1;
    for (var i = 0; i < ring.length; i++) {
      const xi = ring[i][0];
      const yi = ring[i][1];
      const xj = ring[j][0];
      const yj = ring[j][1];

      const intersects =
        yi > lat !== yj > lat &&
        lng < ((xj - xi) * (lat - yi)) / (yj - yi === 0 ? 1e-12 : yj - yi) + xi;
      if (intersects) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  private isPointInPolygon(lng: number, lat: number, polygon: PolygonRings): boolean {
    if (polygon.length === 0) {
      return false;
    }

    const inOuter = this.isPointInRing(lng, lat, polygon[0]);
    if (!inOuter) {
      return false;
    }

    for (var i = 1; i < polygon.length; i++) {
      if (this.isPointInRing(lng, lat, polygon[i])) {
        return false;
      }
    }

    return true;
  }

  private isPointInFeature(lng: number, lat: number, feature: IndexedIrisFeature): boolean {
    if (lng < feature.minLng || lng > feature.maxLng || lat < feature.minLat || lat > feature.maxLat) {
      return false;
    }

    for (const polygon of feature.polygons) {
      if (this.isPointInPolygon(lng, lat, polygon)) {
        return true;
      }
    }

    return false;
  }

  private computeVisibleWidthKm(
    latitude: number,
    zoom: number,
    viewportWidthPx: number,
  ): number {
    const latRadians = (latitude * Math.PI) / 180;
    const metersPerPixel =
      (156543.03392804097 * Math.abs(Math.cos(latRadians))) / Math.pow(2, zoom);
    const widthMeters = metersPerPixel * viewportWidthPx;
    return widthMeters / 1000;
  }

  async hitTestByCoordinates(
    lat: number,
    lng: number,
    zoom?: number,
    viewportWidthPx?: number,
  ) {
    await this.ensureIrisSchema('territory map hit-test');

    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      throw new BadRequestException('Invalid coordinates for territory hit-test');
    }

    if (
      Number.isFinite(zoom) &&
      Number.isFinite(viewportWidthPx) &&
      viewportWidthPx! > 0
    ) {
      const visibleWidthKm = this.computeVisibleWidthKm(
        lat,
        zoom as number,
        viewportWidthPx as number,
      );

      if (visibleWidthKm > TerritoriesService.HIT_TEST_MAX_VISIBLE_WIDTH_KM) {
        return { code_iris: null };
      }
    }

    const index = await this.getIrisGeoIndex();
    const hit = index.find((feature) => this.isPointInFeature(lng, lat, feature));
    if (!hit) {
      return { code_iris: null };
    }

    return { code_iris: hit.codeIris };
  }

  async findByCodeIris(codeIris: string) {
    await this.ensureIrisSchema('territory lookup');
    const code = this.normalizeCodeIris(codeIris);
    const t = await this.territoryRepo.findOne({
      where: { code_iris: code },
      relations: ['owner_club'],
    });
    if (!t) throw new NotFoundException('Territory not found');
    return t;
  }

  async getTerritoryPanel(codeIris: string) {
    await this.ensureIrisSchema('territory panel');
    const territory = await this.findByCodeIris(codeIris);
    const lastEvents = await this.historyRepo.find({
      where: { territory_id: territory.code_iris },
      order: { created_at: 'DESC' },
      take: 10,
      relations: ['from_club', 'to_club'],
    });

    const activeDuel = await this.duelRepo.findOne({
      where: {
        territory_id: territory.code_iris,
        status: 'pending',
      },
      order: { created_at: 'DESC' },
      relations: ['challengerClub', 'defenderClub'],
    });

    return {
      territory,
      active_duel: activeDuel,
      latest_events: lastEvents,
    };
  }

  async history(codeIris: string) {
    await this.ensureIrisSchema('territory history');
    const code = this.normalizeCodeIris(codeIris);
    return this.historyRepo.find({
      where: { territory_id: code },
      relations: ['from_club', 'to_club'],
      order: { created_at: 'DESC' },
      take: 50,
    });
  }

  async updateStatus(codeIris: string, dto: UpdateTerritoryStatusDto, actorUserId: string) {
    await this.ensureIrisSchema('territory status update');
    const territory = await this.findByCodeIris(codeIris);
    const previousStatus = territory.status;

    territory.status = dto.status;
    if (dto.status === 'conquered' && !territory.conquered_at) {
      territory.conquered_at = new Date();
    }

    const saved = await this.territoryRepo.save(territory);

    await this.historyRepo.save(
      this.historyRepo.create({
        territory_id: saved.code_iris,
        from_club_id: saved.owner_club_id,
        to_club_id: saved.owner_club_id,
        event: `status:${previousStatus}->${dto.status}`,
      }),
    );

    this.territoryGateway.emitTerritoryStatusUpdated(saved.code_iris, {
      code_iris: saved.code_iris,
      status: saved.status,
      owner_club_id: saved.owner_club_id,
      actor_user_id: actorUserId,
      reason: dto.reason ?? null,
      updated_at: saved.updated_at,
    });

    return saved;
  }

  async transferOwnership(codeIris: string, toClubId: string | null, event: string) {
    await this.ensureIrisSchema('territory ownership transfer');
    const territory = await this.findByCodeIris(codeIris);
    const fromClubId = territory.owner_club?.id ?? null;

    if (toClubId && !/^[0-9a-fA-F-]{36}$/.test(toClubId)) {
      throw new BadRequestException('Invalid winner club id');
    }

    const entry = this.historyRepo.create({
      territory_id: territory.code_iris,
      from_club: fromClubId ? ({ id: fromClubId } as any) : null,
      to_club: toClubId ? ({ id: toClubId } as any) : null,
      event,
    });
    await this.historyRepo.save(entry);

    territory.owner_club = toClubId ? ({ id: toClubId } as any) : null;
    territory.owner_club_id = toClubId;
    territory.status = toClubId ? 'conquered' : 'available';
    territory.conquered_at = toClubId ? new Date() : null;
    const saved = await this.territoryRepo.save(territory);

    this.territoryGateway.emitTerritoryOwnerUpdated(saved.code_iris, {
      code_iris: saved.code_iris,
      owner_club_id: saved.owner_club_id,
      status: saved.status,
      updated_at: saved.updated_at,
      event,
    });

    return saved;
  }

  /* ── Duels ── */

  async createDuel(dto: CreateDuelDto, challengerUserId: string) {
    await this.ensureIrisSchema('territory duel creation');
    const challengerClubId = await this.resolveUserClubId(challengerUserId);
    const territory = await this.findByCodeIris(dto.territory_id);

    if (territory.owner_club?.id === challengerClubId) {
      throw new BadRequestException('Cannot challenge your own territory');
    }

    const pendingDuel = await this.duelRepo.findOne({
      where: {
        territory_id: dto.territory_id,
        status: 'pending',
      },
    });
    if (pendingDuel) throw new BadRequestException('A duel is already pending for this territory');

    const duel = this.duelRepo.create({
      territory_id: dto.territory_id,
      territory: { code_iris: dto.territory_id } as any,
      challenger_id: challengerUserId,
      challenger_club: challengerClubId,
      defender_club: dto.defender_club_id,
      expires_at: new Date(Date.now() + 48 * 60 * 60 * 1000), // 48h
    });
    const saved = await this.duelRepo.save(duel);

    this.territoryGateway.emitDuelRequest(dto.territory_id, {
      duel_id: saved.id,
      territory_id: saved.territory_id,
      challenger_club_id: saved.challenger_club,
      defender_club_id: saved.defender_club,
      status: saved.status,
      expires_at: saved.expires_at,
    });

    return saved;
  }

  async acceptDuel(duelId: string) {
    const duel = await this.duelRepo.findOne({ where: { id: duelId } });
    if (!duel) throw new NotFoundException('Duel not found');
    if (duel.status !== 'pending') throw new BadRequestException('Duel is not pending');

    duel.status = 'accepted';
    const saved = await this.duelRepo.save(duel);
    this.territoryGateway.emitDuelAccepted(saved.territory_id, {
      duel_id: saved.id,
      territory_id: saved.territory_id,
      status: saved.status,
    });
    return saved;
  }

  async completeDuel(duelId: string, winnerClubId: string) {
    const duel = await this.duelRepo.findOne({
      where: { id: duelId },
      relations: ['territory'],
    });
    if (!duel) throw new NotFoundException('Duel not found');

    if (!winnerClubId) {
      throw new BadRequestException('winner_club_id is required');
    }

    duel.status = 'completed' as any;
    const saved = await this.duelRepo.save(duel);

    const territory = await this.transferOwnership(
      duel.territory.code_iris,
      winnerClubId,
      `duel_won:${duelId}`,
    );

    this.territoryGateway.emitDuelCompleted(duel.territory.code_iris, {
      duel_id: saved.id,
      territory_id: duel.territory.code_iris,
      winner_club_id: winnerClubId,
      territory_status: territory.status,
      owner_club_id: territory.owner_club_id,
    });

    return saved;
  }

  async findPendingDuels(clubId: string) {
    return this.duelRepo.find({
      where: [
        { challenger_club: clubId, status: 'pending' },
        { defender_club: clubId, status: 'pending' },
      ],
      relations: ['territory', 'challengerClub', 'defenderClub'],
      order: { created_at: 'DESC' },
    });
  }

  async findPendingDuelsForUser(userId: string) {
    const clubId = await this.resolveUserClubId(userId);
    return this.findPendingDuels(clubId);
  }
}
