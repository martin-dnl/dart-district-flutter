import { IsString, MinLength, IsOptional } from 'class-validator';

export class SsoCompleteDto {
  @IsString()
  sso_token: string;

  @IsString()
  @MinLength(2)
  display_name: string;

  @IsString()
  @IsOptional()
  level?: string;

  @IsString()
  @IsOptional()
  preferred_hand?: string;
}
