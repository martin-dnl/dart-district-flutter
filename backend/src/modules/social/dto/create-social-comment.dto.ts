import { IsString, MaxLength } from 'class-validator';

export class CreateSocialCommentDto {
  @IsString()
  @MaxLength(500)
  message: string;
}
