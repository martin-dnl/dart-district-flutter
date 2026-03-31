import {
  IsString,
  IsOptional,
  IsBoolean,
  IsNumber,
  IsInt,
  IsDateString,
  Min,
  Matches,
} from 'class-validator';

export class CreateTournamentDto {
  @IsString()
  name: string;

  @IsString()
  @Matches(/^[0-9A-Za-z]{9}$/)
  @IsOptional()
  territory_id?: string;

  @IsString()
  @IsOptional()
  venue?: string;

  @IsBoolean()
  @IsOptional()
  is_territorial?: boolean;

  @IsNumber()
  @IsOptional()
  entry_fee?: number;

  @IsInt()
  @Min(2)
  max_clubs: number;

  @IsDateString()
  scheduled_at: string;
}
