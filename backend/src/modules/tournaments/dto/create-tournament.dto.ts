import {
  IsString,
  IsOptional,
  IsBoolean,
  IsNumber,
  IsInt,
  IsDateString,
  Min,
  Matches,
  IsIn,
  Max,
  IsUUID,
} from 'class-validator';

export class CreateTournamentDto {
  @IsString()
  name: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsString()
  @Matches(/^[0-9A-Za-z]{9}$/)
  @IsOptional()
  territory_id?: string;

  @IsString()
  @IsOptional()
  venue_name?: string;

  @IsString()
  @IsOptional()
  venue_address?: string;

  @IsString()
  @IsOptional()
  city?: string;

  @IsUUID()
  @IsOptional()
  club_id?: string;

  @IsBoolean()
  @IsOptional()
  is_territorial?: boolean;

  @IsString()
  @IsOptional()
  @IsIn(['301', '501', '701', 'cricket', 'chasseur'])
  mode?: string;

  @IsString()
  @IsOptional()
  @IsIn(['double_out', 'single_out', 'master_out'])
  finish?: string;

  @IsNumber()
  @IsOptional()
  entry_fee?: number;

  @IsInt()
  @Min(4)
  @Max(64)
  max_players: number;

  @IsString()
  @IsOptional()
  @IsIn(['single_elimination', 'pools_then_elimination'])
  format?: string;

  @IsInt()
  @IsOptional()
  @Min(2)
  pool_count?: number;

  @IsInt()
  @IsOptional()
  @Min(1)
  qualified_per_pool?: number;

  @IsInt()
  @IsOptional()
  @Min(1)
  legs_per_set_pool?: number;

  @IsInt()
  @IsOptional()
  @Min(1)
  sets_to_win_pool?: number;

  @IsInt()
  @IsOptional()
  @Min(1)
  legs_per_set_bracket?: number;

  @IsInt()
  @IsOptional()
  @Min(1)
  sets_to_win_bracket?: number;

  @IsDateString()
  scheduled_at: string;
}
