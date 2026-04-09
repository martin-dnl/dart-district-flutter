import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { NestExpressApplication } from '@nestjs/platform-express';
import { existsSync } from 'fs';
import { join } from 'path';
import { static as serveStatic } from 'express';
import { AppModule } from './app.module';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  const logger = new Logger('Bootstrap');
  const host = process.env.BACKEND_HOST ?? process.env.HOST ?? '0.0.0.0';
  const port = parseInt(
    process.env.BACKEND_PORT ?? process.env.PORT ?? '3000',
    10,
  );

  // Global prefix
  app.setGlobalPrefix('api/v1');

  // CORS
  const corsOrigin = process.env.CORS_ORIGIN ?? '';
  app.enableCors({
    origin: corsOrigin === '*' ? true : corsOrigin.split(',').filter(Boolean),
    credentials: corsOrigin !== '*',
  });

  // Validation
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  // Filters & Interceptors
  app.useGlobalFilters(new GlobalExceptionFilter());
  app.useGlobalInterceptors(new LoggingInterceptor(), new TransformInterceptor());

  // Local PMTiles assets for development
  // Allow explicit override and common relative fallbacks for different launch cwd.
  const irisCandidates = [
    process.env.IRIS_DATA_DIR?.trim(),
    join(process.cwd(), 'iris_data'),
    join(process.cwd(), '..', 'iris_data'),
  ].filter((value): value is string => Boolean(value && value.trim().length > 0));

  const irisDataDir = irisCandidates.find((candidate) => existsSync(candidate));
  if (irisDataDir) {
    app.use('/tiles', serveStatic(irisDataDir, { index: false }));
    logger.log(`Serving local tiles from ${irisDataDir} at /tiles`);
  } else {
    logger.warn(
      `No iris_data directory found. Checked: ${irisCandidates.join(', ')}`,
    );
  }

  // User-uploaded assets (avatars)
  const uploadsDir = join(process.cwd(), 'uploads');
  app.useStaticAssets(uploadsDir, { prefix: '/uploads' });

  // Swagger
  const config = new DocumentBuilder()
    .setTitle('Dart District API')
    .setDescription('API backend for the Dart District mobile application')
    .setVersion('1.0')
    .addBearerAuth()
    .addTag('auth', 'Authentication & registration')
    .addTag('users', 'User profiles & leaderboard')
    .addTag('clubs', 'Club management & membership')
    .addTag('territories', 'Territory map & duels')
    .addTag('matches', 'Match creation & scoring')
    .addTag('stats', 'Player statistics & ELO')
    .addTag('tournaments', 'Tournament management')
    .addTag('notifications', 'User notifications')
    .addTag('contacts', 'Friends & direct messages')
    .addTag('app-version', 'Mobile app version policies')
    .addTag('qr-codes', 'QR code generation & scanning')
    .addTag('offline-sync', 'Offline sync queue')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  // Start
  await app.listen(port, host);
  logger.log(`Dart District API running on http://${host}:${port}`);
  logger.log(`Swagger docs at http://${host}:${port}/api/docs`);
}

bootstrap();
