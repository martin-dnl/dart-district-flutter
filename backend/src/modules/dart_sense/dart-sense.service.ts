import {
  BadGatewayException,
  BadRequestException,
  Injectable,
  Logger,
} from '@nestjs/common';

@Injectable()
export class DartSenseService {
  private readonly logger = new Logger(DartSenseService.name);

  async detect(image: Express.Multer.File) {
    if (!image) {
      throw new BadRequestException('image is required');
    }

    const baseUrl =
      process.env.DART_SENSE_BASE_URL?.trim() ||
      process.env.DART_SENSE_URL?.trim() ||
      'http://localhost:8001';

    const form = new FormData();
    form.append(
      'image',
      new Blob([new Uint8Array(image.buffer)], {
        type: image.mimetype || 'image/jpeg',
      }),
      image.originalname || 'capture.jpg',
    );

    let response: Response;
    try {
      response = await fetch(`${baseUrl.replace(/\/+$/, '')}/detect`, {
        method: 'POST',
        body: form,
      });
    } catch (error) {
      this.logger.error(`Dart Sense connection failed: ${String(error)}`);
      throw new BadGatewayException('Dart Sense service unavailable');
    }

    let payload: unknown;
    try {
      payload = await response.json();
    } catch (_) {
      throw new BadGatewayException('Invalid response from Dart Sense service');
    }

    if (!response.ok) {
      throw new BadGatewayException('Dart Sense detection failed');
    }

    const body =
      payload && typeof payload === 'object'
        ? (payload as Record<string, unknown>)
        : {};
    const data =
      body['data'] && typeof body['data'] === 'object'
        ? (body['data'] as Record<string, unknown>)
        : body;
    const darts = Array.isArray(data['darts']) ? data['darts'] : [];

    return { darts };
  }
}
