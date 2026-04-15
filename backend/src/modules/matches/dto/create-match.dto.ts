import {
  IsEnum,
  IsInt,
  IsUUID,
  IsOptional,
  IsBoolean,
  IsArray,
  Min,
  IsString,
  Matches,
  IsIn,
} from 'class-validator';

export class CreateMatchDto {
  @IsEnum(['501', '301', 'cricket'])
  mode: '501' | '301' | 'cricket';

  @IsEnum(['double_out', 'straight_out', 'master_out'])
  finish_type: 'double_out' | 'straight_out' | 'master_out';

  @IsInt()
  @Min(1)
  best_of_sets: number;

  @IsInt()
  @Min(1)
  @IsIn([1, 3, 5, 7])
  best_of_legs: number;

  @IsArray()
  @IsUUID('4', { each: true })
  player_ids: string[];

  @IsBoolean()
  @IsOptional()
  is_territorial?: boolean;

  @IsBoolean()
  @IsOptional()
  is_ranked?: boolean;

  @IsString()
  @Matches(/^[0-9A-Za-z]{9}$/)
  @IsOptional()
  territory_id?: string;

  @IsUUID()
  @IsOptional()
  club_id?: string;

  @IsUUID()
  @IsOptional()
  tournament_id?: string;
}
