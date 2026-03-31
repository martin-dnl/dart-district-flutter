import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { QrCode } from './entities/qr-code.entity';
import { randomBytes } from 'crypto';

@Injectable()
export class QrService {
  constructor(
    @InjectRepository(QrCode) private readonly repo: Repository<QrCode>,
  ) {}

  async generate(territoryId: string, venue: string) {
    const code = randomBytes(16).toString('hex');
    const qr = this.repo.create({
      territory_id: territoryId,
      territory: { code_iris: territoryId } as any,
      venue_name: venue,
      code,
      is_active: true,
    });
    return this.repo.save(qr);
  }

  async findByCode(code: string) {
    const qr = await this.repo.findOne({
      where: { code, is_active: true },
      relations: ['territory', 'territory.owner_club'],
    });
    if (!qr) throw new NotFoundException('QR code not found or inactive');
    return qr;
  }

  async findByTerritory(territoryId: string) {
    return this.repo.find({
      where: { territory: { code_iris: territoryId }, is_active: true },
    });
  }

  async deactivate(id: string) {
    const qr = await this.repo.findOne({ where: { id } });
    if (!qr) throw new NotFoundException('QR code not found');
    qr.is_active = false;
    return this.repo.save(qr);
  }
}
