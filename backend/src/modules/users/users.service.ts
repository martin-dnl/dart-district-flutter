import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity';
import { UpdateUserDto } from './dto/update-user.dto';
import { normalizeLimit } from '../../common/utils/normalize-limit';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private readonly repo: Repository<User>,
  ) {}

  async findById(id: string) {
    const user = await this.repo.findOne({
      where: { id },
      relations: ['stats', 'club_memberships', 'club_memberships.club'],
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async update(id: string, dto: UpdateUserDto) {
    await this.repo.update(id, dto);
    return this.findById(id);
  }

  async search(query: string, limit = 20) {
    const take = normalizeLimit(limit, 20);

    return this.repo
      .createQueryBuilder('u')
      .where('u.username ILIKE :q', { q: `%${query}%` })
      .orderBy('u.elo', 'DESC')
      .take(take)
      .getMany();
  }

  async leaderboard(limit = 50) {
    const take = normalizeLimit(limit, 50);

    return this.repo.find({
      order: { elo: 'DESC' },
      take,
      select: ['id', 'username', 'avatar_url', 'elo', 'level'],
    });
  }

  async remove(id: string) {
    const result = await this.repo.softDelete(id);
    if (result.affected === 0) throw new NotFoundException('User not found');
  }
}
