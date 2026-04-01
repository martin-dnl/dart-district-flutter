import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { AppVersionService } from './app-version.service';

@ApiTags('app-version')
@Controller('app/version')
export class AppVersionController {
  constructor(private readonly appVersionService: AppVersionService) {}

  @Get()
  getVersionPolicy(
    @Query('platform') platform: string,
    @Query('app_version') appVersion?: string,
  ) {
    return this.appVersionService.getPolicyForClient(platform, appVersion);
  }
}
