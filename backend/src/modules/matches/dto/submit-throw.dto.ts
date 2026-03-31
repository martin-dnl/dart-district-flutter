import { IsInt, IsString, IsBoolean, IsOptional, Min, Max } from 'class-validator';

export class SubmitThrowDto {
  @IsInt()
  @Min(1)
  round_number: number;

  @IsInt()
  @Min(1)
  @Max(3)
  dart_number: number;

  @IsString()
  segment: string; // e.g. "T20", "D16", "S1", "BULL", "DBULL", "MISS"

  @IsInt()
  @Min(0)
  score: number;

  @IsBoolean()
  @IsOptional()
  is_checkout?: boolean;
}
