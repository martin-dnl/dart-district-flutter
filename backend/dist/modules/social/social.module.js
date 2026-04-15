"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SocialModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const friendship_entity_1 = require("../contacts/entities/friendship.entity");
const match_entity_1 = require("../matches/entities/match.entity");
const social_post_comment_entity_1 = require("./entities/social-post-comment.entity");
const social_post_like_entity_1 = require("./entities/social-post-like.entity");
const social_post_entity_1 = require("./entities/social-post.entity");
const social_controller_1 = require("./social.controller");
const social_service_1 = require("./social.service");
let SocialModule = class SocialModule {
};
exports.SocialModule = SocialModule;
exports.SocialModule = SocialModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([
                social_post_entity_1.SocialPost,
                social_post_like_entity_1.SocialPostLike,
                social_post_comment_entity_1.SocialPostComment,
                friendship_entity_1.Friendship,
                match_entity_1.Match,
            ]),
        ],
        controllers: [social_controller_1.SocialController],
        providers: [social_service_1.SocialService],
    })
], SocialModule);
//# sourceMappingURL=social.module.js.map