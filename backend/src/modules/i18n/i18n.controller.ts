import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { I18nService } from './i18n.service';

@ApiTags('i18n')
@Controller()
export class I18nController {
  constructor(private readonly i18nService: I18nService) {}

  @Get('languages')
  getLanguages(@Query('available') available?: string) {
    const availableOnly = (available ?? '').toLowerCase() === 'true';
    return this.i18nService.getLanguages(availableOnly);
  }

  @Get('translations/:languageCode')
  getTranslations(@Param('languageCode') languageCode: string) {
    return this.i18nService.getTranslations(languageCode);
  }
}
