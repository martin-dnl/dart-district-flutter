import { IsUUID } from 'class-validator';

export class SendFriendRequestDto {
  @IsUUID()
  receiver_id: string;
}
