import { Repository } from 'typeorm';
import { Language } from './entities/language.entity';
import { Translation } from './entities/translation.entity';
export declare class I18nService {
    private readonly languageRepo;
    private readonly translationRepo;
    constructor(languageRepo: Repository<Language>, translationRepo: Repository<Translation>);
    getLanguages(availableOnly?: boolean): Promise<Language[]>;
    getTranslations(languageCode: string): Promise<Record<string, string>>;
}
