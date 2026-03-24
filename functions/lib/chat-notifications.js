"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.matchGroupChatMessageNotifications = exports.chatMessageNotifications = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firebase_functions_1 = require("firebase-functions");
const admin = __importStar(require("firebase-admin"));
/**
 * Cloud Function that triggers when a new chat message is created in a hangout
 * Sends push notifications to participants who have notifications enabled
 */
exports.chatMessageNotifications = (0, firestore_1.onDocumentCreated)("posts/{postId}/chat/{messageId}", async (event) => {
    var _a;
    try {
        const messageData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
        const postId = event.params.postId;
        const messageId = event.params.messageId;
        if (!messageData) {
            firebase_functions_1.logger.warn(`No data found for message ${messageId} in post ${postId}`);
            return;
        }
        firebase_functions_1.logger.info(`Processing chat message notification for post ${postId}`, {
            messageId: messageId,
            senderId: messageData.senderId,
            senderName: messageData.senderName,
            type: messageData.type,
        });
        // Skip system messages - they don't need notifications
        if (messageData.type === "system") {
            firebase_functions_1.logger.info(`Skipping notification for system message ${messageId}`);
            return;
        }
        // Get the post/hangout data
        const postDoc = await admin.firestore()
            .collection("posts")
            .doc(postId)
            .get();
        if (!postDoc.exists) {
            firebase_functions_1.logger.warn(`Post ${postId} not found`);
            return;
        }
        const postData = postDoc.data();
        // Skip notifications for deleted or locked posts
        if (postData.deleted || postData.isLocked) {
            firebase_functions_1.logger.info(`Skipping notifications for deleted/locked post ${postId}`);
            return;
        }
        // Get all participants except the sender
        const recipientIds = postData.participantIds.filter((participantId) => participantId !== messageData.senderId);
        await sendChatNotifications({
            chatRoomId: postId,
            messageId: messageId,
            messageData: messageData,
            notificationType: "chat_message",
            prefsField: "hangoutChatNotifications",
            dataPayload: {
                type: "chat_message",
                postId: postId,
                messageId: messageId,
                senderId: messageData.senderId,
                senderName: messageData.senderName,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
        }, recipientIds);
    }
    catch (error) {
        firebase_functions_1.logger.error("Error processing chat notification:", error);
    }
});
/**
 * Cloud Function that triggers when a new chat message is created in a matched group
 * Sends push notifications to members who have notifications enabled
 */
exports.matchGroupChatMessageNotifications = (0, firestore_1.onDocumentCreated)("matched_groups/{groupId}/messages/{messageId}", async (event) => {
    var _a;
    try {
        const messageData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
        const groupId = event.params.groupId;
        const messageId = event.params.messageId;
        if (!messageData) {
            firebase_functions_1.logger.warn(`No data found for message ${messageId} in matched group ${groupId}`);
            return;
        }
        firebase_functions_1.logger.info(`Processing chat message notification for matched group ${groupId}`, {
            messageId: messageId,
            senderId: messageData.senderId,
            senderName: messageData.senderName,
            type: messageData.type,
        });
        if (messageData.type === "system") {
            firebase_functions_1.logger.info(`Skipping notification for system message ${messageId}`);
            return;
        }
        // Get the matched group data
        const groupDoc = await admin.firestore()
            .collection("matched_groups")
            .doc(groupId)
            .get();
        if (!groupDoc.exists) {
            firebase_functions_1.logger.warn(`Matched group ${groupId} not found`);
            return;
        }
        const groupData = groupDoc.data();
        if (groupData.status !== "active") {
            firebase_functions_1.logger.info(`Skipping notifications for non-active matched group ${groupId} (status: ${groupData.status})`);
            return;
        }
        // Get all members except the sender
        const recipientIds = groupData.memberIds.filter((memberId) => memberId !== messageData.senderId);
        await sendChatNotifications({
            chatRoomId: groupId,
            messageId: messageId,
            messageData: messageData,
            notificationType: "match_chat_message",
            prefsField: "matchGroupChatNotifications",
            dataPayload: {
                type: "match_chat_message",
                matchedGroupId: groupId,
                messageId: messageId,
                senderId: messageData.senderId,
                senderName: messageData.senderName,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
        }, recipientIds);
    }
    catch (error) {
        firebase_functions_1.logger.error("Error processing matched group chat notification:", error);
    }
});
/**
 * Shared logic: send chat notifications to a list of recipients
 */
async function sendChatNotifications(ctx, recipientIds) {
    if (recipientIds.length === 0) {
        firebase_functions_1.logger.info(`No recipients to notify for message ${ctx.messageId}`);
        return;
    }
    firebase_functions_1.logger.info(`Found ${recipientIds.length} potential recipients`, {
        recipientIds: recipientIds,
    });
    const notificationPromises = recipientIds.map((recipientId) => sendNotificationToUser(recipientId, ctx));
    const results = await Promise.allSettled(notificationPromises);
    const successCount = results.filter((r) => r.status === "fulfilled").length;
    const failureCount = results.filter((r) => r.status === "rejected").length;
    firebase_functions_1.logger.info(`Completed processing chat notifications for message ${ctx.messageId}`, {
        chatRoomId: ctx.chatRoomId,
        totalRecipients: recipientIds.length,
        successCount: successCount,
        failureCount: failureCount,
    });
}
/**
 * Send notification to a specific user if they have notifications enabled
 */
async function sendNotificationToUser(userId, ctx) {
    var _a;
    let userData;
    try {
        const userDoc = await admin.firestore()
            .collection("users")
            .doc(userId)
            .get();
        if (!userDoc.exists) {
            firebase_functions_1.logger.warn(`User ${userId} not found`);
            return;
        }
        userData = userDoc.data();
        if (!userData.fcmToken) {
            firebase_functions_1.logger.info(`User ${userId} has no FCM token - skipping notification`);
            return;
        }
        // Check notification preferences - default to true (enabled) if not set
        const notificationPrefs = userData[ctx.prefsField] || {};
        const notificationsEnabled = (_a = notificationPrefs[ctx.chatRoomId]) !== null && _a !== void 0 ? _a : true;
        if (!notificationsEnabled) {
            firebase_functions_1.logger.info(`User ${userId} has disabled notifications for ${ctx.chatRoomId}`);
            return;
        }
        const maxContentLength = 100;
        const contentPreview = ctx.messageData.content.length > maxContentLength
            ? `${ctx.messageData.content.substring(0, maxContentLength)}...`
            : ctx.messageData.content;
        const message = {
            token: userData.fcmToken,
            notification: {
                title: `${ctx.messageData.senderName}`,
                body: contentPreview,
            },
            data: ctx.dataPayload,
            android: {
                notification: {
                    icon: "ic_notification",
                    color: "#FF6B35",
                    sound: "default",
                    channelId: "chat_notifications",
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                        badge: 1,
                        category: "chat_notification",
                    },
                },
            },
        };
        const response = await admin.messaging().send(message);
        firebase_functions_1.logger.info(`Successfully sent chat notification to user ${userId}`, {
            chatRoomId: ctx.chatRoomId,
            messageId: ctx.messageId,
            responseId: response,
        });
    }
    catch (error) {
        firebase_functions_1.logger.error(`Failed to send chat notification to user ${userId}:`, {
            chatRoomId: ctx.chatRoomId,
            messageId: ctx.messageId,
            error: error,
            errorMessage: error.message,
            errorCode: error.code,
            errorDetails: error.details,
            fcmToken: (userData === null || userData === void 0 ? void 0 : userData.fcmToken) ? `${userData.fcmToken.substring(0, 20)}...` : "none",
        });
        throw error;
    }
}
//# sourceMappingURL=chat-notifications.js.map