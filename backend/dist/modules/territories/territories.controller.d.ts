import { TerritoriesService } from './territories.service';
import { CreateDuelDto } from './dto/create-duel.dto';
import { QueryTerritoryStatusesDto } from './dto/query-territory-statuses.dto';
import { UpdateTerritoryStatusDto } from './dto/update-territory-status.dto';
import { UpdateTerritoryOwnerDto } from './dto/update-territory-owner.dto';
export declare class TerritoriesController {
    private readonly territoriesService;
    constructor(territoriesService: TerritoriesService);
    tilesetMetadata(): Promise<{
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
    mapStatuses(query: QueryTerritoryStatusesDto): Promise<{
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
    mapHit(latRaw: string, lngRaw: string, zoomRaw?: string, viewportWidthRaw?: string): Promise<{
        code_iris: null;
    } | {
        code_iris: string;
    }>;
    findAll(): Promise<any>;
    findOne(codeIris: string): Promise<import("./entities/territory.entity").Territory>;
    panel(codeIris: string): Promise<{
        territory: import("./entities/territory.entity").Territory;
        active_duel: import("./entities/duel.entity").Duel | null;
        latest_events: import("./entities/territory-history.entity").TerritoryHistory[];
    }>;
    history(codeIris: string): Promise<import("./entities/territory-history.entity").TerritoryHistory[]>;
    updateStatus(codeIris: string, dto: UpdateTerritoryStatusDto, req: {
        user: {
            id: string;
        };
    }): Promise<import("./entities/territory.entity").Territory>;
    updateOwner(codeIris: string, dto: UpdateTerritoryOwnerDto): Promise<import("./entities/territory.entity").Territory>;
    createDuel(dto: CreateDuelDto, req: {
        user: {
            id: string;
        };
    }): Promise<import("./entities/duel.entity").Duel>;
    pendingDuels(req: {
        user: {
            id: string;
        };
    }): Promise<import("./entities/duel.entity").Duel[]>;
    acceptDuel(id: string): Promise<import("./entities/duel.entity").Duel>;
    completeDuel(id: string, winnerClubId: string): Promise<import("./entities/duel.entity").Duel>;
}
