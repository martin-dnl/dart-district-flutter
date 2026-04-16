import { IsString, MaxLength } from 'class-validator';

export class CreateSocialReportDto {
  @IsString()
  @MaxLength(500)
  reason: string;
}
