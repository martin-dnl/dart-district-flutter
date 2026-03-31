import { IsUUID } from 'class-validator';

export class RegisterClubDto {
  @IsUUID()
  club_id: string;
}
