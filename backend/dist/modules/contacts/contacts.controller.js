"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ContactsController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const jwt_auth_guard_1 = require("../auth/guards/jwt-auth.guard");
const contacts_service_1 = require("./contacts.service");
const add_friend_dto_1 = require("./dto/add-friend.dto");
const send_friend_request_dto_1 = require("./dto/send-friend-request.dto");
let ContactsController = class ContactsController {
    constructor(contactsService) {
        this.contactsService = contactsService;
    }
    incomingRequests(req) {
        return this.contactsService.listIncomingRequests(req.user.id);
    }
    outgoingRequests(req) {
        return this.contactsService.listOutgoingRequests(req.user.id);
    }
    sendRequest(req, dto) {
        return this.contactsService.sendFriendRequest(req.user.id, dto.receiver_id);
    }
    acceptRequest(req, requestId) {
        return this.contactsService.acceptFriendRequest(req.user.id, requestId);
    }
    rejectRequest(req, requestId) {
        return this.contactsService.rejectFriendRequest(req.user.id, requestId);
    }
    listFriends(req) {
        return this.contactsService.listFriends(req.user.id);
    }
    addFriend(req, dto) {
        return this.contactsService.addFriend(req.user.id, dto.friend_id);
    }
    removeFriend(req, friendId) {
        return this.contactsService.removeFriend(req.user.id, friendId);
    }
    blockUser(req, userId) {
        return this.contactsService.blockUser(req.user.id, userId);
    }
    unblockUser(req, userId) {
        return this.contactsService.unblockUser(req.user.id, userId);
    }
    status(req, userId) {
        return this.contactsService.getFriendshipStatus(req.user.id, userId);
    }
    listConversation(req, contactId, limit) {
        return this.contactsService.listConversation(req.user.id, contactId, limit);
    }
    markRead(req, contactId) {
        return this.contactsService.markConversationRead(req.user.id, contactId);
    }
    unread(req) {
        return this.contactsService.getUnreadCount(req.user.id);
    }
};
exports.ContactsController = ContactsController;
__decorate([
    (0, common_1.Get)('requests/incoming'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], ContactsController.prototype, "incomingRequests", null);
__decorate([
    (0, common_1.Get)('requests/outgoing'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], ContactsController.prototype, "outgoingRequests", null);
__decorate([
    (0, common_1.Post)('requests'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, send_friend_request_dto_1.SendFriendRequestDto]),
    __metadata("design:returntype", void 0)
], ContactsController.prototype, "sendRequest", null);
__decorate([
    (0, common_1.Post)('requests/:requestId/accept'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('requestId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], ContactsController.prototype, "acceptRequest", null);
__decorate([
    (0, common_1.Post)('requests/:requestId/reject'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('requestId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], ContactsController.prototype, "rejectRequest", null);
__decorate([
    (0, common_1.Get)('friends'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], ContactsController.prototype, "listFriends", null);
__decorate([
    (0, common_1.Post)('friends'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, add_friend_dto_1.AddFriendDto]),
    __metadata("design:returntype", void 0)
], ContactsController.prototype, "addFriend", null);
__decorate([
    (0, common_1.Delete)('friends/:friendId'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('friendId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], ContactsController.prototype, "removeFriend", null);
__decorate([
    (0, common_1.Post)('block/:userId'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], ContactsController.prototype, "blockUser", null);
__decorate([
    (0, common_1.Delete)('block/:userId'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], ContactsController.prototype, "unblockUser", null);
__decorate([
    (0, common_1.Get)('status/:userId'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], ContactsController.prototype, "status", null);
__decorate([
    (0, common_1.Get)('messages/:contactId'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('contactId', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, Number]),
    __metadata("design:returntype", void 0)
], ContactsController.prototype, "listConversation", null);
__decorate([
    (0, common_1.Post)('messages/:contactId/read'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('contactId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], ContactsController.prototype, "markRead", null);
__decorate([
    (0, common_1.Get)('unread'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], ContactsController.prototype, "unread", null);
exports.ContactsController = ContactsController = __decorate([
    (0, swagger_1.ApiTags)('contacts'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('contacts'),
    __metadata("design:paramtypes", [contacts_service_1.ContactsService])
], ContactsController);
//# sourceMappingURL=contacts.controller.js.map