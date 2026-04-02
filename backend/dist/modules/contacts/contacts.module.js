"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ContactsModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const contacts_controller_1 = require("./contacts.controller");
const contacts_service_1 = require("./contacts.service");
const friendship_entity_1 = require("./entities/friendship.entity");
const friend_request_entity_1 = require("./entities/friend-request.entity");
const user_block_entity_1 = require("./entities/user-block.entity");
const user_entity_1 = require("../users/entities/user.entity");
const direct_message_entity_1 = require("../realtime/entities/direct-message.entity");
let ContactsModule = class ContactsModule {
};
exports.ContactsModule = ContactsModule;
exports.ContactsModule = ContactsModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([
                friendship_entity_1.Friendship,
                friend_request_entity_1.FriendRequest,
                user_block_entity_1.UserBlock,
                user_entity_1.User,
                direct_message_entity_1.DirectMessage,
            ]),
        ],
        controllers: [contacts_controller_1.ContactsController],
        providers: [contacts_service_1.ContactsService],
        exports: [contacts_service_1.ContactsService],
    })
], ContactsModule);
//# sourceMappingURL=contacts.module.js.map