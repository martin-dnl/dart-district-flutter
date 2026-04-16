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
exports.SocialController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const jwt_auth_guard_1 = require("../auth/guards/jwt-auth.guard");
const create_social_comment_dto_1 = require("./dto/create-social-comment.dto");
const create_social_post_dto_1 = require("./dto/create-social-post.dto");
const create_social_report_dto_1 = require("./dto/create-social-report.dto");
const social_service_1 = require("./social.service");
let SocialController = class SocialController {
    constructor(socialService) {
        this.socialService = socialService;
    }
    feed(req, limit, offset) {
        return this.socialService.listFeed(req.user.id, limit, offset);
    }
    createPost(req, dto) {
        return this.socialService.createPost(req.user.id, dto);
    }
    likePost(req, postId) {
        return this.socialService.likePost(req.user.id, postId);
    }
    unlikePost(req, postId) {
        return this.socialService.unlikePost(req.user.id, postId);
    }
    addComment(req, postId, dto) {
        return this.socialService.addComment(req.user.id, postId, dto);
    }
    reportPost(req, postId, dto) {
        return this.socialService.reportPost(req.user.id, postId, dto);
    }
};
exports.SocialController = SocialController;
__decorate([
    (0, common_1.Get)('feed'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Query)('limit')),
    __param(2, (0, common_1.Query)('offset')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Number, Number]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "feed", null);
__decorate([
    (0, common_1.Post)('posts'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, create_social_post_dto_1.CreateSocialPostDto]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "createPost", null);
__decorate([
    (0, common_1.Post)('posts/:postId/likes'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('postId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "likePost", null);
__decorate([
    (0, common_1.Delete)('posts/:postId/likes'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('postId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "unlikePost", null);
__decorate([
    (0, common_1.Post)('posts/:postId/comments'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('postId', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, create_social_comment_dto_1.CreateSocialCommentDto]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "addComment", null);
__decorate([
    (0, common_1.Post)('posts/:postId/reports'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('postId', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, create_social_report_dto_1.CreateSocialReportDto]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "reportPost", null);
exports.SocialController = SocialController = __decorate([
    (0, swagger_1.ApiTags)('social'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('social'),
    __metadata("design:paramtypes", [social_service_1.SocialService])
], SocialController);
//# sourceMappingURL=social.controller.js.map