import { IsDateString, IsIn, IsOptional, IsString } from 'class-validator';

export class QueryTerritoryStatusesDto {
  @IsOptional()
  @IsDateString()
  updated_since?: string;

  @IsOptional()
  @IsIn(['available', 'locked', 'alert', 'conquered', 'conflict'])
  status?: string;

  @IsOptional()
  @IsString()
  dep_code?: string;
}
