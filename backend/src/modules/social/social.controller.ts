import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateSocialPostDto } from './dto/create-social-post.dto';
import { SocialService } from './social.service';

@ApiTags('social')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('social')
export class SocialController {
  constructor(private readonly socialService: SocialService) {}

  @Get('feed')
  feed(
    @Req() req: { user: { id: string } },
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
  ) {
    return this.socialService.listFeed(req.user.id, limit, offset);
  }

  @Post('posts')
  createPost(
    @Req() req: { user: { id: string } },
    @Body() dto: CreateSocialPostDto,
  ) {
    return this.socialService.createPost(req.user.id, dto);
  }
}
