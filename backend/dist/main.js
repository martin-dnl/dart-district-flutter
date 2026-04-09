"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const core_1 = require("@nestjs/core");
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const fs_1 = require("fs");
const path_1 = require("path");
const express_1 = require("express");
const app_module_1 = require("./app.module");
const global_exception_filter_1 = require("./common/filters/global-exception.filter");
const logging_interceptor_1 = require("./common/interceptors/logging.interceptor");
const transform_interceptor_1 = require("./common/interceptors/transform.interceptor");
async function bootstrap() {
    const app = await core_1.NestFactory.create(app_module_1.AppModule);
    const logger = new common_1.Logger('Bootstrap');
    const host = process.env.BACKEND_HOST ?? process.env.HOST ?? '0.0.0.0';
    const port = parseInt(process.env.BACKEND_PORT ?? process.env.PORT ?? '3000', 10);
    app.setGlobalPrefix('api/v1');
    const corsOrigin = process.env.CORS_ORIGIN ?? '';
    app.enableCors({
        origin: corsOrigin === '*' ? true : corsOrigin.split(',').filter(Boolean),
        credentials: corsOrigin !== '*',
    });
    app.useGlobalPipes(new common_1.ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
        transformOptions: { enableImplicitConversion: true },
    }));
    app.useGlobalFilters(new global_exception_filter_1.GlobalExceptionFilter());
    app.useGlobalInterceptors(new logging_interceptor_1.LoggingInterceptor(), new transform_interceptor_1.TransformInterceptor());
    const irisCandidates = [
        process.env.IRIS_DATA_DIR?.trim(),
        (0, path_1.join)(process.cwd(), 'iris_data'),
        (0, path_1.join)(process.cwd(), '..', 'iris_data'),
    ].filter((value) => Boolean(value && value.trim().length > 0));
    const irisDataDir = irisCandidates.find((candidate) => (0, fs_1.existsSync)(candidate));
    if (irisDataDir) {
        app.use('/tiles', (0, express_1.static)(irisDataDir, { index: false }));
        logger.log(`Serving local tiles from ${irisDataDir} at /tiles`);
    }
    else {
        logger.warn(`No iris_data directory found. Checked: ${irisCandidates.join(', ')}`);
    }
    const uploadsDir = (0, path_1.join)(process.cwd(), 'uploads');
    app.useStaticAssets(uploadsDir, { prefix: '/uploads' });
    const config = new swagger_1.DocumentBuilder()
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
    const document = swagger_1.SwaggerModule.createDocument(app, config);
    swagger_1.SwaggerModule.setup('api/docs', app, document);
    await app.listen(port, host);
    logger.log(`Dart District API running on http://${host}:${port}`);
    logger.log(`Swagger docs at http://${host}:${port}/api/docs`);
}
bootstrap();
//# sourceMappingURL=main.js.map