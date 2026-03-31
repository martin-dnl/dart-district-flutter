import { IsString } from 'class-validator';

export class SocialLoginDto {
  @IsString()
  id_token: string;
}
