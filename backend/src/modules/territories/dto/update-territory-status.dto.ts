import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateTerritoryStatusDto {
  @IsIn(['available', 'locked', 'alert', 'conquered', 'conflict'])
  status: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  reason?: string;
}
