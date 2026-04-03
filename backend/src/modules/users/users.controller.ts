import {
  BadRequestException,
  Controller,
  ForbiddenException,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  Req,
  UploadedFile,
  UseInterceptors,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiConsumes } from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { UsersService } from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  me(@Req() req: { user: { id: string; is_guest?: boolean; username?: string } }) {
    if (req.user.is_guest || req.user.id === 'guest') {
      return {
        id: 'guest',
        username: req.user.username ?? 'Invité',
        email: null,
        avatar_url: null,
        elo: 1000,
        is_admin: false,
        created_at: new Date().toISOString(),
        stats: {
          matches_played: 0,
          matches_won: 0,
          avg_score: 0,
          checkout_rate: 0,
          total_180s: 0,
          count_140_plus: 0,
          count_100_plus: 0,
          best_avg: 0,
        },
        club_memberships: [],
      };
    }

    return this.usersService.findById(req.user.id);
  }

  @Get('me/badges')
  myBadges(@Req() req: { user: { id: string } }) {
    return this.usersService.findMyBadges(req.user.id);
  }

  @Get('me/settings')
  mySettings(
    @Req() req: { user: { id: string; is_guest?: boolean } },
    @Query('key') key?: string,
  ) {
    if (req.user.is_guest || req.user.id === 'guest') {
      throw new ForbiddenException('Guest account cannot access user settings');
    }
    return this.usersService.getSettings(req.user.id, key);
  }

  @Get('leaderboard')
  leaderboard(@Query('limit') limit?: number) {
    return this.usersService.leaderboard(limit);
  }

  @Get('search')
  search(@Query('q') q: string, @Query('limit') limit?: number) {
    return this.usersService.search(q, limit);
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.usersService.findById(id);
  }

  @Patch('me')
  update(@Req() req: { user: { id: string; is_guest?: boolean } }, @Body() dto: UpdateUserDto) {
    if (req.user.is_guest || req.user.id === 'guest') {
      throw new ForbiddenException('Guest account cannot be updated');
    }
    return this.usersService.update(req.user.id, dto);
  }

  @Patch('me/settings')
  updateSetting(
    @Req() req: { user: { id: string; is_guest?: boolean } },
    @Body() body: { key?: string; value?: string },
  ) {
    if (req.user.is_guest || req.user.id === 'guest') {
      throw new ForbiddenException('Guest account cannot be updated');
    }

    const key = (body.key ?? '').trim();
    const value = (body.value ?? '').trim();
    if (!key || !value) {
      throw new BadRequestException('key and value are required');
    }

    return this.usersService.upsertSetting(req.user.id, key, value);
  }

  @Post('me/avatar')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileInterceptor('avatar', {
      storage: memoryStorage(),
      limits: {
        fileSize: 5 * 1024 * 1024,
      },
    }),
  )
  uploadAvatar(
    @Req() req: { user: { id: string; is_guest?: boolean } },
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (req.user.is_guest || req.user.id === 'guest') {
      throw new ForbiddenException('Guest account has no avatar upload');
    }

    if (!file) {
      throw new BadRequestException('avatar file is required');
    }

    return this.usersService.uploadAvatar(req.user.id, file);
  }

  @Delete('me')
  remove(@Req() req: { user: { id: string; is_guest?: boolean } }) {
    if (req.user.is_guest || req.user.id === 'guest') {
      throw new ForbiddenException('Guest account cannot be deleted');
    }
    return this.usersService.remove(req.user.id);
  }
}
