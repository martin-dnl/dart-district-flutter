import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { Friendship } from '../contacts/entities/friendship.entity';
import { Match } from '../matches/entities/match.entity';
import { SocialPostComment } from './entities/social-post-comment.entity';
import { SocialPostLike } from './entities/social-post-like.entity';
import { SocialPost } from './entities/social-post.entity';
import { SocialController } from './social.controller';
import { SocialService } from './social.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      SocialPost,
      SocialPostLike,
      SocialPostComment,
      Friendship,
      Match,
    ]),
  ],
  controllers: [SocialController],
  providers: [SocialService],
})
export class SocialModule {}
