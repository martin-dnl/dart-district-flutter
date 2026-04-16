import { User } from '../../users/entities/user.entity';
export declare class PlayerTerritoryPoints {
    id: string;
    user_id: string;
    code_iris: string;
    points: number;
    created_at: Date;
    updated_at: Date;
    user: User;
}
