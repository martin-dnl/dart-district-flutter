import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateSocialCommentDto } from './dto/create-social-comment.dto';
import { CreateSocialPostDto } from './dto/create-social-post.dto';
import { CreateSocialReportDto } from './dto/create-social-report.dto';
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

  @Post('posts/:postId/likes')
  likePost(
    @Req() req: { user: { id: string } },
    @Param('postId', ParseUUIDPipe) postId: string,
  ) {
    return this.socialService.likePost(req.user.id, postId);
  }

  @Delete('posts/:postId/likes')
  unlikePost(
    @Req() req: { user: { id: string } },
    @Param('postId', ParseUUIDPipe) postId: string,
  ) {
    return this.socialService.unlikePost(req.user.id, postId);
  }

  @Post('posts/:postId/comments')
  addComment(
    @Req() req: { user: { id: string } },
    @Param('postId', ParseUUIDPipe) postId: string,
    @Body() dto: CreateSocialCommentDto,
  ) {
    return this.socialService.addComment(req.user.id, postId, dto);
  }

  @Post('posts/:postId/reports')
  reportPost(
    @Req() req: { user: { id: string } },
    @Param('postId', ParseUUIDPipe) postId: string,
    @Body() dto: CreateSocialReportDto,
  ) {
    return this.socialService.reportPost(req.user.id, postId, dto);
  }
}
