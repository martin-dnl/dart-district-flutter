import { DataSource, Repository } from 'typeorm';
import { Territory } from './entities/territory.entity';
import { TerritoryHistory } from './entities/territory-history.entity';
import { Duel } from './entities/duel.entity';
import { CreateDuelDto } from './dto/create-duel.dto';
import { QueryTerritoryStatusesDto } from './dto/query-territory-statuses.dto';
import { UpdateTerritoryStatusDto } from './dto/update-territory-status.dto';
import { TerritoryGateway } from '../realtime/gateways/territory.gateway';
import { ClubMember } from '../clubs/entities/club-member.entity';
import { TerritoryTileset } from './entities/territory-tileset.entity';
export declare class TerritoriesService {
    private readonly territoryRepo;
    private readonly historyRepo;
    private readonly duelRepo;
    private readonly clubMemberRepo;
    private readonly tilesetRepo;
    private readonly territoryGateway;
    private readonly dataSource;
    private static readonly HIT_TEST_MAX_VISIBLE_WIDTH_KM;
    private static readonly GEOJSON_NEAREST_FALLBACK_KM;
    private readonly logger;
    private schemaInfoPromise?;
    private irisGeoIndexPromise?;
    constructor(territoryRepo: Repository<Territory>, historyRepo: Repository<TerritoryHistory>, duelRepo: Repository<Duel>, clubMemberRepo: Repository<ClubMember>, tilesetRepo: Repository<TerritoryTileset>, territoryGateway: TerritoryGateway, dataSource: DataSource);
    private resolveTilesetSourceUrl;
    private withResolvedTilesetSourceUrl;
    private fallbackTilesetMetadata;
    private isMissingRelationError;
    private isMissingColumnError;
    private getSchemaInfo;
    private loadSchemaInfo;
    private ensureIrisSchema;
    private findAllLegacy;
    private normalizeCodeIris;
    private resolveUserClubId;
    getTilesetMetadata(): Promise<{
        key: string;
        format: string;
        source_url: string;
        attribution: string;
        minzoom: number;
        maxzoom: number;
        bounds_west: number;
        bounds_south: number;
        bounds_east: number;
        bounds_north: number;
        center_lng: number;
        center_lat: number;
        center_zoom: number;
        layer_name: string;
        is_active: boolean;
    } | {
        id: string;
        key: string;
        format: string;
        source_url: string;
        attribution: string;
        minzoom: number;
        maxzoom: number;
        bounds_west: number | null;
        bounds_south: number | null;
        bounds_east: number | null;
        bounds_north: number | null;
        center_lng: number | null;
        center_lat: number | null;
        center_zoom: number | null;
        layer_name: string | null;
        is_active: boolean;
        created_at: Date;
        updated_at: Date;
    }>;
    getActiveIrisCodes(): Promise<any>;
    findAll(): Promise<any>;
    getMapStatuses(query: QueryTerritoryStatusesDto): Promise<{
        count: number;
        statuses: never[];
        schema_warning: string;
    } | {
        count: number;
        statuses: any[];
        schema_warning?: undefined;
    }>;
    getMapData(): Promise<{
        territories: never[];
        clubs: never[];
        warning: string;
    } | {
        territories: {
            id: string;
            code_iris: string;
            name: string;
            status: string;
            owner_club_id: string | null;
            owner_club: {
                id: string;
                name: string;
            } | null;
            centroid_lat: number;
            centroid_lng: number;
            updated_at: Date;
        }[];
        clubs: any;
        warning?: undefined;
    }>;
    getClubZones(): Promise<{
        count: any;
        zones: any;
    }>;
    private resolveIrisGeoJsonPath;
    private getIrisGeoIndex;
    private loadIrisGeoIndex;
    private extractPolygons;
    private parsePolygon;
    private isPointInRing;
    private isPointInPolygon;
    private isPointInFeature;
    private isValidCoordinates;
    private haversineDistanceKm;
    private findNearestFeatureByBboxDistance;
    resolveCodeIrisByPolygon(lat: number, lng: number, maxDistanceKm?: number): Promise<string | null>;
    private computeVisibleWidthKm;
    hitTestByCoordinates(lat: number, lng: number, zoom?: number, viewportWidthPx?: number): Promise<{
        code_iris: null;
    } | {
        code_iris: string;
    }>;
    findByCodeIrisOrNull(codeIris: string): Promise<Territory | null>;
    findByCodeIris(codeIris: string): Promise<Territory>;
    getTerritoryPanel(codeIris: string): Promise<{
        territory: Territory;
        active_duel: Duel | null;
        latest_events: TerritoryHistory[];
        top_clubs: {
            rank: number;
            club_id: string;
            club_name: string;
            points: number;
        }[];
        top_players: {
            rank: number;
            user_id: string;
            username: string;
            elo: number;
            points: number;
        }[];
    }>;
    history(codeIris: string): Promise<TerritoryHistory[]>;
    updateStatus(codeIris: string, dto: UpdateTerritoryStatusDto, actorUserId: string): Promise<Territory>;
    transferOwnership(codeIris: string, toClubId: string | null, event: string): Promise<Territory>;
    createDuel(dto: CreateDuelDto, challengerUserId: string): Promise<Duel>;
    acceptDuel(duelId: string): Promise<Duel>;
    completeDuel(duelId: string, winnerClubId: string): Promise<Duel>;
    findPendingDuels(clubId: string): Promise<Duel[]>;
    findPendingDuelsForUser(userId: string): Promise<Duel[]>;
}
