import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from './entities/user.entity';
import { UserBadge } from '../badges/entities/user-badge.entity';
import { Friendship } from '../contacts/entities/friendship.entity';
import { FriendRequest } from '../contacts/entities/friend-request.entity';
import { RefreshToken } from '../auth/entities/refresh-token.entity';
import { UserSetting } from './entities/user-setting.entity';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      User,
      UserBadge,
      Friendship,
      FriendRequest,
      RefreshToken,
      UserSetting,
    ]),
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
