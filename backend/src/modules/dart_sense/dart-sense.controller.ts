import {
  Controller,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { ApiBearerAuth, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
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
}
