import { IsUUID, IsEnum, IsOptional } from 'class-validator';

export class ManageMemberDto {
  @IsUUID()
  user_id: string;

  @IsEnum(['president', 'captain', 'player'])
  @IsOptional()
  role?: 'president' | 'captain' | 'player';
}
