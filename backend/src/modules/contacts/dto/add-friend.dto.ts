import { IsUUID } from 'class-validator';

export class AddFriendDto {
  @IsUUID()
  friend_id: string;
}
