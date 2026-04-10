import {
  Controller,
  Body,
  Post,
  Query,
  UploadedFile,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { ApiBearerAuth, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { FileInterceptor, FilesInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { DartSenseService } from './dart-sense.service';

@ApiTags('dart-sense')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('dart-sense')
export class DartSenseController {
  constructor(private readonly dartSenseService: DartSenseService) {}

  @Post('detect')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileInterceptor('image', {
      storage: memoryStorage(),
      limits: {
        fileSize: 10 * 1024 * 1024,
      },
    }),
  )
  detect(@UploadedFile() file?: Express.Multer.File) {
    return this.dartSenseService.detect(file as Express.Multer.File);
  }

  @Post('detect/batch')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FilesInterceptor('images', 24, {
      storage: memoryStorage(),
      limits: {
        fileSize: 10 * 1024 * 1024,
      },
    }),
  )
  detectBatch(
    @UploadedFiles() files?: Express.Multer.File[],
    @Query('min_occurrences') minOccurrences?: string,
    @Query('max_frames') maxFrames?: string,
  ) {
    const parsedMin = minOccurrences ? Number.parseInt(minOccurrences, 10) : 2;
    const parsedMax = maxFrames ? Number.parseInt(maxFrames, 10) : 24;
    return this.dartSenseService.detectBatch(files ?? [], parsedMin, parsedMax);
  }

  @Post('feedback')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileInterceptor('image', {
      storage: memoryStorage(),
      limits: {
        fileSize: 10 * 1024 * 1024,
      },
    }),
  )
  feedback(
    @UploadedFile() file?: Express.Multer.File,
    @Body('zone') zone?: string,
    @Body('multiplier') multiplier?: string,
    @Body('source') source?: string,
    @Body('note') note?: string,
  ) {
    const parsedZone = Number.parseInt(zone ?? '', 10);
    const parsedMultiplier = Number.parseInt(multiplier ?? '', 10);
    return this.dartSenseService.feedback(
      file as Express.Multer.File,
      parsedZone,
      parsedMultiplier,
      source,
      note,
    );
  }
}
