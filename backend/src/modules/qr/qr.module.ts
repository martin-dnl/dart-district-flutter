import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { QrCode } from './entities/qr-code.entity';
import { QrService } from './qr.service';
import { QrController } from './qr.controller';

@Module({
  imports: [TypeOrmModule.forFeature([QrCode])],
  controllers: [QrController],
  providers: [QrService],
  exports: [QrService],
})
export class QrModule {}
