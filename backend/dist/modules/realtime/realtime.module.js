"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RealtimeModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const chat_message_entity_1 = require("./entities/chat-message.entity");
const direct_message_entity_1 = require("./entities/direct-message.entity");
const match_gateway_1 = require("./gateways/match.gateway");
const chat_gateway_1 = require("./gateways/chat.gateway");
const territory_gateway_1 = require("./gateways/territory.gateway");
const system_gateway_1 = require("./gateways/system.gateway");
let RealtimeModule = class RealtimeModule {
};
exports.RealtimeModule = RealtimeModule;
exports.RealtimeModule = RealtimeModule = __decorate([
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([chat_message_entity_1.ChatMessage, direct_message_entity_1.DirectMessage])],
        providers: [match_gateway_1.MatchGateway, chat_gateway_1.ChatGateway, territory_gateway_1.TerritoryGateway, system_gateway_1.SystemGateway],
        exports: [match_gateway_1.MatchGateway, chat_gateway_1.ChatGateway, territory_gateway_1.TerritoryGateway, system_gateway_1.SystemGateway],
    })
], RealtimeModule);
//# sourceMappingURL=realtime.module.js.map