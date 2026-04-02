import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ContactsController } from './contacts.controller';
import { ContactsService } from './contacts.service';
import { Friendship } from './entities/friendship.entity';
import { FriendRequest } from './entities/friend-request.entity';
import { UserBlock } from './entities/user-block.entity';
import { User } from '../users/entities/user.entity';
import { DirectMessage } from '../realtime/entities/direct-message.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Friendship,
      FriendRequest,
      UserBlock,
      User,
      DirectMessage,
    ]),
  ],
  controllers: [ContactsController],
  providers: [ContactsService],
  exports: [ContactsService],
})
export class ContactsModule {}
