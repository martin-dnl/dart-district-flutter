"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const typeorm_1 = require("@nestjs/typeorm");
const throttler_1 = require("@nestjs/throttler");
const core_1 = require("@nestjs/core");
const auth_module_1 = require("./modules/auth/auth.module");
const users_module_1 = require("./modules/users/users.module");
const clubs_module_1 = require("./modules/clubs/clubs.module");
const territories_module_1 = require("./modules/territories/territories.module");
const matches_module_1 = require("./modules/matches/matches.module");
const stats_module_1 = require("./modules/stats/stats.module");
const tournaments_module_1 = require("./modules/tournaments/tournaments.module");
const realtime_module_1 = require("./modules/realtime/realtime.module");
const offline_sync_module_1 = require("./modules/offline_sync/offline-sync.module");
const notifications_module_1 = require("./modules/notifications/notifications.module");
const qr_module_1 = require("./modules/qr/qr.module");
const contacts_module_1 = require("./modules/contacts/contacts.module");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            config_1.ConfigModule.forRoot({ isGlobal: true }),
            typeorm_1.TypeOrmModule.forRoot({
                type: 'postgres',
                host: process.env.POSTGRES_HOST || 'localhost',
                port: parseInt(process.env.POSTGRES_PORT ?? '5432', 10),
                username: process.env.POSTGRES_USER || 'dart_district',
                password: process.env.POSTGRES_PASSWORD || 'dart_district',
                database: process.env.POSTGRES_DB || 'dart_district',
                autoLoadEntities: true,
                synchronize: process.env.TYPEORM_SYNCHRONIZE === 'true',
                logging: process.env.NODE_ENV !== 'production',
            }),
            throttler_1.ThrottlerModule.forRoot([{
                    ttl: parseInt(process.env.THROTTLE_TTL ?? '60000', 10),
                    limit: parseInt(process.env.THROTTLE_LIMIT ?? '100', 10),
                }]),
            auth_module_1.AuthModule,
            users_module_1.UsersModule,
            clubs_module_1.ClubsModule,
            territories_module_1.TerritoriesModule,
            matches_module_1.MatchesModule,
            stats_module_1.StatsModule,
            tournaments_module_1.TournamentsModule,
            realtime_module_1.RealtimeModule,
            offline_sync_module_1.OfflineSyncModule,
            notifications_module_1.NotificationsModule,
            qr_module_1.QrModule,
            contacts_module_1.ContactsModule,
        ],
        providers: [
            {
                provide: core_1.APP_GUARD,
                useClass: throttler_1.ThrottlerGuard,
            },
        ],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map