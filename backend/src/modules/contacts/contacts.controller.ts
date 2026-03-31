import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Body,
  Req,
  Query,
  ParseUUIDPipe,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ContactsService } from './contacts.service';
import { AddFriendDto } from './dto/add-friend.dto';
import { SendFriendRequestDto } from './dto/send-friend-request.dto';

@ApiTags('contacts')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('contacts')
export class ContactsController {
  constructor(private readonly contactsService: ContactsService) {}

  @Get('requests/incoming')
  incomingRequests(@Req() req: { user: { id: string } }) {
    return this.contactsService.listIncomingRequests(req.user.id);
  }

  @Get('requests/outgoing')
  outgoingRequests(@Req() req: { user: { id: string } }) {
    return this.contactsService.listOutgoingRequests(req.user.id);
  }

  @Post('requests')
  sendRequest(
    @Req() req: { user: { id: string } },
    @Body() dto: SendFriendRequestDto,
  ) {
    return this.contactsService.sendFriendRequest(req.user.id, dto.receiver_id);
  }

  @Post('requests/:requestId/accept')
  acceptRequest(
    @Req() req: { user: { id: string } },
    @Param('requestId', ParseUUIDPipe) requestId: string,
  ) {
    return this.contactsService.acceptFriendRequest(req.user.id, requestId);
  }

  @Post('requests/:requestId/reject')
  rejectRequest(
    @Req() req: { user: { id: string } },
    @Param('requestId', ParseUUIDPipe) requestId: string,
  ) {
    return this.contactsService.rejectFriendRequest(req.user.id, requestId);
  }

  @Get('friends')
  listFriends(@Req() req: { user: { id: string } }) {
    return this.contactsService.listFriends(req.user.id);
  }

  @Post('friends')
  addFriend(@Req() req: { user: { id: string } }, @Body() dto: AddFriendDto) {
    return this.contactsService.addFriend(req.user.id, dto.friend_id);
  }

  @Delete('friends/:friendId')
  removeFriend(
    @Req() req: { user: { id: string } },
    @Param('friendId', ParseUUIDPipe) friendId: string,
  ) {
    return this.contactsService.removeFriend(req.user.id, friendId);
  }

  @Get('messages/:contactId')
  listConversation(
    @Req() req: { user: { id: string } },
    @Param('contactId', ParseUUIDPipe) contactId: string,
    @Query('limit') limit?: number,
  ) {
    return this.contactsService.listConversation(req.user.id, contactId, limit);
  }

  @Post('messages/:contactId/read')
  markRead(
    @Req() req: { user: { id: string } },
    @Param('contactId', ParseUUIDPipe) contactId: string,
  ) {
    return this.contactsService.markConversationRead(req.user.id, contactId);
  }

  @Get('unread')
  unread(@Req() req: { user: { id: string } }) {
    return this.contactsService.getUnreadCount(req.user.id);
  }
}
