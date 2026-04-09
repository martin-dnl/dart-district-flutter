import { Module } from '@nestjs/common';
import { DartSenseController } from './dart-sense.controller';
import { DartSenseService } from './dart-sense.service';

@Module({
  controllers: [DartSenseController],
  providers: [DartSenseService],
})
export class DartSenseModule {}
