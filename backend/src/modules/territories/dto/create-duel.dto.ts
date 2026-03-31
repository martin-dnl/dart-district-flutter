import { IsUUID, IsOptional, IsString, Matches } from 'class-validator';

export class CreateDuelDto {
  @IsString()
  @Matches(/^[0-9A-Za-z]{9}$/)
  territory_id: string;

  @IsUUID()
  defender_club_id: string;

  @IsString()
  @IsOptional()
  qr_code_id?: string;
}
