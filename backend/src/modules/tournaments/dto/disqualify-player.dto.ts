import { IsString, MinLength } from 'class-validator';

export class DisqualifyPlayerDto {
  @IsString()
  @MinLength(2)
  reason: string;
}
