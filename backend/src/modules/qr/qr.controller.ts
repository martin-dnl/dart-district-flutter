import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Body,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { QrService } from './qr.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('qr-codes')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('qr-codes')
export class QrController {
  constructor(private readonly qrService: QrService) {}

  @Post()
  generate(@Body() body: { territory_id: string; venue: string }) {
    return this.qrService.generate(body.territory_id, body.venue);
  }

  @Get('scan/:code')
  scan(@Param('code') code: string) {
    return this.qrService.findByCode(code);
  }

  @Get('territory/:territoryId')
  findByTerritory(@Param('territoryId') territoryId: string) {
    return this.qrService.findByTerritory(territoryId);
  }

  @Patch(':id/deactivate')
  deactivate(@Param('id', ParseUUIDPipe) id: string) {
    return this.qrService.deactivate(id);
  }
}
