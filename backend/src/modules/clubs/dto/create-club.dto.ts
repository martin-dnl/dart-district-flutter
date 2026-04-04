import {
  IsString,
  IsOptional,
  IsNumber,
  MaxLength,
  Min,
  Max,
  IsObject,
} from 'class-validator';

export class CreateClubDto {
  @IsString()
  name: string;

  @IsString()
  @IsOptional()
  address?: string;

  @IsString()
  @IsOptional()
  @MaxLength(100)
  city?: string;

  @IsString()
  @IsOptional()
  @MaxLength(10)
  postal_code?: string;

  @IsString()
  @IsOptional()
  @MaxLength(100)
  country?: string;

  @IsNumber()
  @IsOptional()
  latitude?: number;

  @IsNumber()
  @IsOptional()
  longitude?: number;

  @IsNumber()
  @IsOptional()
  @Min(0)
  @Max(100)
  dart_boards_count?: number;

  @IsOptional()
  @IsObject()
  opening_hours?: Record<string, { open: string; close: string }>;

  @IsString()
  @IsOptional()
  google_place_id?: string;

  @IsString()
  @IsOptional()
  code_iris?: string;
}
