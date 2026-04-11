import { IsString, IsUUID, MaxLength } from 'class-validator';

export class CreateSocialPostDto {
  @IsUUID()
  match_id: string;

  @IsString()
  @MaxLength(280)
  description: string;
}
