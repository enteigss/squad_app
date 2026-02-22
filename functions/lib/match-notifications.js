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
exports.matchNotifications = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firebase_functions_1 = require("firebase-functions");
const admin = __importStar(require("firebase-admin"));
/**
 * Cloud Function that triggers when a new matched group is created.
 * Sends push notifications to all members letting them know they've been matched.
 */
exports.matchNotifications = (0, firestore_1.onDocumentCreated)("matched_groups/{groupId}", async (event) => {
    var _a;
    try {
        const groupData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
        const groupId = event.params.groupId;
        if (!groupData) {
            firebase_functions_1.logger.warn(`No data found for matched group ${groupId}`);
            return;
        }
        firebase_functions_1.logger.info(`Processing match notification for group ${groupId}`, {
            groupId: groupId,
            memberIds: groupData.memberIds,
            memberCount: groupData.memberIds.length,
        });
        // Get all members to notify
        const memberIds = groupData.memberIds;
        if (!memberIds || memberIds.length === 0) {
            firebase_functions_1.logger.warn(`No members found in matched group ${groupId}`);
            return;
        }
        firebase_functions_1.logger.info(`Found ${memberIds.length} members to notify`, {
            memberIds: memberIds,
        });
        // Send notifications to each member
        const notificationPromises = memberIds.map((memberId) => sendMatchNotificationToUser(memberId, groupId, groupData));
        const results = await Promise.allSettled(notificationPromises);
        // Count successes and failures
        const successCount = results.filter((r) => r.status === "fulfilled").length;
        const failureCount = results.filter((r) => r.status === "rejected").length;
        firebase_functions_1.logger.info(`Completed processing match notifications for group ${groupId}`, {
            groupId: groupId,
            totalMembers: memberIds.length,
            successCount: successCount,
            failureCount: failureCount,
        });
    }
    catch (error) {
        firebase_functions_1.logger.error("Error processing match notification:", error);
        // Don't rethrow - we don't want to fail group creation if notifications fail
    }
});
/**
 * Send match notification to a specific user
 */
async function sendMatchNotificationToUser(userId, groupId, groupData) {
    let userData;
    try {
        // Get user document
        const userDoc = await admin.firestore()
            .collection("users")
            .doc(userId)
            .get();
        if (!userDoc.exists) {
            firebase_functions_1.logger.warn(`User ${userId} not found`);
            return;
        }
        userData = userDoc.data();
        // Check if user has FCM token
        if (!userData.fcmToken) {
            firebase_functions_1.logger.info(`User ${userId} has no FCM token - skipping notification`);
            return;
        }
        // Create notification body from shared interests
        const notificationBody = groupData.sharedInterests || "Check out what you have in common!";
        const message = {
            token: userData.fcmToken,
            notification: {
                title: "See your new connection!",
                body: notificationBody,
            },
            data: {
                type: "new_match",
                matchedGroupId: groupId,
                matchId: groupData.matchId || "",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
                notification: {
                    icon: "ic_notification",
                    color: "#FF6B35",
                    sound: "default",
                    channelId: "match_notifications",
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                        badge: 1,
                        category: "match_notification",
                    },
                },
            },
        };
        // Send the notification
        const response = await admin.messaging().send(message);
        firebase_functions_1.logger.info(`Successfully sent match notification to user ${userId}`, {
            groupId: groupId,
            responseId: response,
        });
    }
    catch (error) {
        firebase_functions_1.logger.error(`Failed to send match notification to user ${userId}:`, {
            groupId: groupId,
            error: error,
            errorMessage: error.message,
            errorCode: error.code,
            fcmToken: (userData === null || userData === void 0 ? void 0 : userData.fcmToken) ? `${userData.fcmToken.substring(0, 20)}...` : "none",
        });
        // Re-throw to mark this promise as rejected
        throw error;
    }
}
//# sourceMappingURL=match-notifications.js.map