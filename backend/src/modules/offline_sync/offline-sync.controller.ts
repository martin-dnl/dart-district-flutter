import {
  Controller,
  Post,
  Get,
  Patch,
  Body,
  Query,
  Param,
  UseGuards,
  Req,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { OfflineSyncService } from './offline-sync.service';
import { PushSyncDto } from './dto/push-sync.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('offline-sync')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('sync')
export class OfflineSyncController {
  constructor(private readonly syncService: OfflineSyncService) {}

  @Post('push')
  push(@Req() req: { user: { id: string } }, @Body() items: PushSyncDto[]) {
    return this.syncService.push(req.user.id, items);
  }

  @Get('pull')
  pull(@Req() req: { user: { id: string } }, @Query('since') since?: string) {
    return this.syncService.pull(req.user.id, since);
  }

  @Patch(':id/resolve')
  resolve(
    @Param('id', ParseUUIDPipe) id: string,
    @Body('resolution') resolution: 'keep_local' | 'keep_remote',
  ) {
    return this.syncService.resolveConflict(id, resolution);
  }
}
