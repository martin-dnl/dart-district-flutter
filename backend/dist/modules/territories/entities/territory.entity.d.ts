import { Club } from '../../clubs/entities/club.entity';
export declare class Territory {
    code_iris: string;
    name: string;
    insee_com: string | null;
    nom_com: string | null;
    nom_iris: string | null;
    iris_type: string | null;
    dep_code: string | null;
    dep_name: string | null;
    region_code: string | null;
    region_name: string | null;
    population: number | null;
    centroid_lat: number;
    centroid_lng: number;
    area_m2: number | null;
    status: string;
    owner_club_id: string | null;
    conquered_at: Date | null;
    created_at: Date;
    updated_at: Date;
    owner_club: Club;
}
