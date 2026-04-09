import { Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
export interface JwtPayload {
    sub: string;
    email: string;
    username: string;
    is_guest?: boolean;
    is_admin?: boolean;
}
declare const JwtStrategy_base: new (...args: any[]) => Strategy;
export declare class JwtStrategy extends JwtStrategy_base {
    constructor(config: ConfigService);
    validate(payload: JwtPayload): {
        id: string;
        email: string;
        username: string;
        is_guest: boolean;
        is_admin: boolean;
    };
}
export {};
