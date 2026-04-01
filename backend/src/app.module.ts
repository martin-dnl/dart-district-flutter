import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';

import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { ClubsModule } from './modules/clubs/clubs.module';
import { TerritoriesModule } from './modules/territories/territories.module';
import { MatchesModule } from './modules/matches/matches.module';
import { StatsModule } from './modules/stats/stats.module';
import { TournamentsModule } from './modules/tournaments/tournaments.module';
import { RealtimeModule } from './modules/realtime/realtime.module';
import { OfflineSyncModule } from './modules/offline_sync/offline-sync.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { QrModule } from './modules/qr/qr.module';
import { ContactsModule } from './modules/contacts/contacts.module';
import { AppVersionModule } from './modules/app_version/app-version.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),

    TypeOrmModule.forRoot({
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

    ThrottlerModule.forRoot([{
      ttl: parseInt(process.env.THROTTLE_TTL ?? '60000', 10),
      limit: parseInt(process.env.THROTTLE_LIMIT ?? '100', 10),
    }]),

    // Feature modules
    AuthModule,
    UsersModule,
    ClubsModule,
    TerritoriesModule,
    MatchesModule,
    StatsModule,
    TournamentsModule,
    RealtimeModule,
    OfflineSyncModule,
    NotificationsModule,
    QrModule,
    ContactsModule,
    AppVersionModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}
