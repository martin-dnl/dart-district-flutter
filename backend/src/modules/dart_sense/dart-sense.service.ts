import {
  BadGatewayException,
  BadRequestException,
  Injectable,
  Logger,
} from '@nestjs/common';

@Injectable()
export class DartSenseService {
  private readonly logger = new Logger(DartSenseService.name);

  private get baseUrl(): string {
    return (
      process.env.DART_SENSE_BASE_URL?.trim() ||
      process.env.DART_SENSE_URL?.trim() ||
      'http://localhost:8001'
    );
  }

  private appendFileToForm(
    form: FormData,
    fieldName: string,
    image: Express.Multer.File,
  ) {
    form.append(
      fieldName,
      new Blob([new Uint8Array(image.buffer)], {
        type: image.mimetype || 'image/jpeg',
      }),
      image.originalname || 'capture.jpg',
    );
  }

  async detect(image: Express.Multer.File) {
    if (!image) {
      throw new BadRequestException('image is required');
    }

    const form = new FormData();
    this.appendFileToForm(form, 'image', image);

    let response: Response;
    try {
      response = await fetch(`${this.baseUrl.replace(/\/+$/, '')}/detect`, {
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

  async detectBatch(
    images: Express.Multer.File[],
    minOccurrences = 2,
    maxFrames = 24,
  ) {
    if (!images.length) {
      throw new BadRequestException('images are required');
    }

    const form = new FormData();
    for (const image of images.slice(0, Math.max(1, maxFrames))) {
      this.appendFileToForm(form, 'images', image);
    }

    const min = Number.isFinite(minOccurrences)
      ? Math.min(10, Math.max(1, minOccurrences))
      : 2;
    const max = Number.isFinite(maxFrames)
      ? Math.min(60, Math.max(1, maxFrames))
      : 24;

    let response: Response;
    try {
      response = await fetch(
        `${this.baseUrl.replace(/\/+$/, '')}/detect/batch?min_occurrences=${min}&max_frames=${max}`,
        {
          method: 'POST',
          body: form,
        },
      );
    } catch (error) {
      this.logger.error(`Dart Sense batch connection failed: ${String(error)}`);
      throw new BadGatewayException('Dart Sense service unavailable');
    }

    let payload: unknown;
    try {
      payload = await response.json();
    } catch (_) {
      throw new BadGatewayException('Invalid response from Dart Sense service');
    }

    if (!response.ok) {
      throw new BadGatewayException('Dart Sense batch detection failed');
    }

    const body =
      payload && typeof payload === 'object'
        ? (payload as Record<string, unknown>)
        : {};
    const data =
      body['data'] && typeof body['data'] === 'object'
        ? (body['data'] as Record<string, unknown>)
        : body;

    return {
      darts: Array.isArray(data['darts']) ? data['darts'] : [],
      frames: Array.isArray(data['frames']) ? data['frames'] : [],
      framesProcessed:
        typeof data['frames_processed'] === 'number' ? data['frames_processed'] : 0,
      minOccurrences:
        typeof data['min_occurrences'] === 'number' ? data['min_occurrences'] : min,
    };
  }

  async feedback(
    image: Express.Multer.File,
    zone: number,
    multiplier: number,
    source?: string,
    note?: string,
  ) {
    if (!image) {
      throw new BadRequestException('image is required');
    }
    if (!Number.isInteger(zone) || zone < 1 || zone > 25) {
      throw new BadRequestException('zone must be between 1 and 25');
    }
    if (!Number.isInteger(multiplier) || multiplier < 1 || multiplier > 3) {
      throw new BadRequestException('multiplier must be between 1 and 3');
    }
    if (zone === 25 && multiplier > 2) {
      throw new BadRequestException('bull multiplier must be 1 or 2');
    }

    const form = new FormData();
    this.appendFileToForm(form, 'image', image);
    form.append('zone', `${zone}`);
    form.append('multiplier', `${multiplier}`);
    form.append('source', (source ?? 'mobile_app').trim() || 'mobile_app');
    if (note && note.trim().length > 0) {
      form.append('note', note.trim().slice(0, 240));
    }

    let response: Response;
    try {
      response = await fetch(`${this.baseUrl.replace(/\/+$/, '')}/feedback`, {
        method: 'POST',
        body: form,
      });
    } catch (error) {
      this.logger.error(`Dart Sense feedback connection failed: ${String(error)}`);
      throw new BadGatewayException('Dart Sense service unavailable');
    }

    let payload: unknown;
    try {
      payload = await response.json();
    } catch (_) {
      throw new BadGatewayException('Invalid response from Dart Sense service');
    }

    if (!response.ok) {
      throw new BadGatewayException('Dart Sense feedback failed');
    }

    const body =
      payload && typeof payload === 'object'
        ? (payload as Record<string, unknown>)
        : {};
    const data =
      body['data'] && typeof body['data'] === 'object'
        ? (body['data'] as Record<string, unknown>)
        : body;

    return {
      sample:
        data['sample'] && typeof data['sample'] === 'object'
          ? data['sample']
          : null,
      message:
        typeof data['message'] === 'string'
          ? data['message']
          : 'Feedback saved',
    };
  }
}
