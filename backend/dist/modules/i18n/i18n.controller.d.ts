import { I18nService } from './i18n.service';
export declare class I18nController {
    private readonly i18nService;
    constructor(i18nService: I18nService);
    getLanguages(available?: string): Promise<import("./entities/language.entity").Language[]>;
    getTranslations(languageCode: string): Promise<Record<string, string>>;
}
