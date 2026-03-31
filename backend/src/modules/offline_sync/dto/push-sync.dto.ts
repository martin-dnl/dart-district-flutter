import { IsString, IsEnum, IsObject, IsOptional, IsUUID } from 'class-validator';

export class PushSyncDto {
  @IsString()
  entity_type: string;

  @IsUUID()
  @IsOptional()
  entity_id?: string;

  @IsEnum(['create', 'update', 'delete'])
  action: 'create' | 'update' | 'delete';

  @IsObject()
  payload: Record<string, unknown>;
}
