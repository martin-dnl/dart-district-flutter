import { IsString, IsOptional, IsNumber, IsLatitude, IsLongitude } from 'class-validator';

export class CreateClubDto {
  @IsString()
  name: string;

  @IsString()
  @IsOptional()
  address?: string;

  @IsNumber()
  @IsOptional()
  latitude?: number;

  @IsNumber()
  @IsOptional()
  longitude?: number;

  @IsString()
  @IsOptional()
  code_iris?: string;
}
