import { Language } from './language.entity';
export declare class Translation {
    id: string;
    key: string;
    language_code: string;
    value: string;
    created_at: Date;
    updated_at: Date;
    language: Language;
}
