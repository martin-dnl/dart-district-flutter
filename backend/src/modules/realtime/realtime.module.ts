import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ChatMessage } from './entities/chat-message.entity';
import { DirectMessage } from './entities/direct-message.entity';
import { MatchGateway } from './gateways/match.gateway';
import { ChatGateway } from './gateways/chat.gateway';
import { TerritoryGateway } from './gateways/territory.gateway';
import { SystemGateway } from './gateways/system.gateway';

@Module({
  imports: [TypeOrmModule.forFeature([ChatMessage, DirectMessage])],
  providers: [MatchGateway, ChatGateway, TerritoryGateway, SystemGateway],
  exports: [MatchGateway, ChatGateway, TerritoryGateway, SystemGateway],
})
export class RealtimeModule {}
