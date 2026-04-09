import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Language } from './entities/language.entity';
import { Translation } from './entities/translation.entity';

@Injectable()
export class I18nService {
  constructor(
    @InjectRepository(Language)
    private readonly languageRepo: Repository<Language>,
    @InjectRepository(Translation)
    private readonly translationRepo: Repository<Translation>,
  ) {}

  async getLanguages(availableOnly = false) {
    const qb = this.languageRepo
      .createQueryBuilder('language')
      .orderBy('language.country_name', 'ASC');

    if (availableOnly) {
      qb.where('language.is_available = :available', { available: true });
    }

    return qb.getMany();
  }

  async getTranslations(languageCode: string) {
    const code = languageCode.trim();
    const rows = await this.translationRepo.find({
      where: { language_code: code },
      order: { key: 'ASC' },
    });

    return rows.reduce<Record<string, string>>((acc, row) => {
      acc[row.key] = row.value;
      return acc;
    }, {});
  }
}
