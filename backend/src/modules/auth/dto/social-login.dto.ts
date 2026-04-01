import { IsOptional, IsString } from 'class-validator';

export class SocialLoginDto {
  @IsOptional()
  @IsString()
  id_token?: string;

  @IsOptional()
  @IsString()
  access_token?: string;
}
