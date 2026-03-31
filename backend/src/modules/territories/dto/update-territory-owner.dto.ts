import { IsOptional, IsUUID } from 'class-validator';

export class UpdateTerritoryOwnerDto {
  @IsOptional()
  @IsUUID('4')
  owner_club_id?: string | null;

  @IsOptional()
  @IsUUID('4')
  winner_club_id?: string;

  @IsOptional()
  event?: string;
}
