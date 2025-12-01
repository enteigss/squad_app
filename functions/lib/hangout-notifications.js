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
exports.sendHangoutUpdateNotification = exports.sendLeaveNotification = exports.sendJoinNotification = exports.hangoutNotifications = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const admin = __importStar(require("firebase-admin"));
/**
 * Helper function to format activity text for notifications
 * Returns format: "{activity} at {location}" or just "{activity}" or just "{location}"
 */
function formatActivityText(post) {
    let text = "";
    // Get activity name
    if (post.activity === "other" && post.customActivity) {
        text = post.customActivity;
    }
    else if (post.activity) {
        const activityMap = {
            "diningHall": "Eating",
            "studying": "Studying",
            "walking": "Walking",
            "fitRec": "Working out",
            "chilling": "Chilling",
            "other": "",
        };
        text = activityMap[post.activity] || "";
    }
    // Add location
    if (post.location) {
        text = text ? `${text} at ${post.location}` : post.location;
    }
    return text;
}
/**
 * Cloud Function that triggers when a new hangout (post) is created
 * Sends push notifications to appropriate FCM topics based on gender preferences
 */
exports.hangoutNotifications = (0, firestore_1.onDocumentCreated)("posts/{postId}", async (event) => {
    var _a;
    try {
        const postData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
        const postId = event.params.postId;
        if (!postData) {
            firebase_functions_1.logger.warn(`No data found for post ${postId}`);
            return;
        }
        // Skip notifications for deleted or locked posts
        if (postData.deleted || postData.isLocked) {
            firebase_functions_1.logger.info(`Skipping notifications for deleted/locked post ${postId}`);
            return;
        }
        // DEBUG NOTIFICATION
        /*
        logger.info("Sending debug notification");
  
        const debugTopic = "new_hangouts_all_genders";
  
        const simplePayload = {
          notification: {
            title: "Test Notification",
            body: `This is a simple test triggered by post ${postId}`,
          },
        };
  
        await sendNotificationToTopic(debugTopic, simplePayload, postData, postId);
        */
        firebase_functions_1.logger.info(`Processing new hangout notification for post ${postId}`, {
            activity: postData.activity,
            location: postData.location,
            authorName: postData.authorName,
            genderPreferences: postData.genderPreferences,
        });
        // Determine which topics to send notifications to
        const topics = determineNotificationTopics(postData.genderPreferences);
        if (topics.length === 0) {
            firebase_functions_1.logger.warn(`No topics determined for post ${postId} with preferences:`, postData.genderPreferences);
            return;
        }
        // The platform-specific payloads are now created separately
        const notificationPayload = createNotificationBody(postData);
        // Send notifications to each topic
        const promises = topics.map((topic) => sendNotificationToTopic(topic, notificationPayload, postData, postId));
        await Promise.allSettled(promises);
        firebase_functions_1.logger.info(`Completed processing notifications for post ${postId}`, {
            topics: topics,
            topicCount: topics.length,
        });
    }
    catch (error) {
        firebase_functions_1.logger.error("Error processing hangout notification:", error);
        // Don't rethrow - we don't want to fail post creation if notifications fail
    }
});
/**
 * Determines which FCM topics should receive notifications based on gender preferences
 */
function determineNotificationTopics(genderPreferences) {
    // Your original logic here is correct and can be reused.
    const topics = [];
    const hasAllGenders = genderPreferences.includes("Men") &&
        genderPreferences.includes("Women") &&
        genderPreferences.includes("Non-binary");
    if (hasAllGenders) {
        topics.push("new_hangouts_all_genders");
    }
    else {
        for (const preference of genderPreferences) {
            switch (preference) {
                case "Men":
                    topics.push("new_hangouts_bu_men");
                    break;
                case "Women":
                    topics.push("new_hangouts_bu_women");
                    break;
                case "Non-binary":
                    topics.push("new_hangouts_bu_nonbinary");
                    break;
                default:
                    firebase_functions_1.logger.warn(`Unknown gender preference: ${preference}`);
                    break;
            }
        }
    }
    return [...new Set(topics)];
}
/**
 * Creates the notification body and data payloads (common for all platforms)
 */
function createNotificationBody(postData) {
    const activityText = formatActivityText(postData);
    const bodyText = activityText
        ? `${postData.authorName} just posted: ${activityText}`
        : `${postData.authorName} just posted`;
    // This function returns a simple object with `notification` and `data` keys.
    return {
        notification: {
            body: bodyText,
        },
        data: {
            type: "new_hangout",
            hangout_id: postData.id,
            author_name: postData.authorName,
            author_id: postData.authorId,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
    };
}
/**
 * Sends notification to a specific FCM topic using the modern API
 */
async function sendNotificationToTopic(topic, commonPayload, postData, postId) {
    try {
        firebase_functions_1.logger.info(`Sending notification to topic: ${topic}`, {
            postId: postId,
            activity: postData.activity,
            location: postData.location,
        });
        // Construct the full message payload for the unified `send` method
        /* const message = {
          ...commonPayload,
          topic: topic, // This is the key field for topic messaging
          android: {
            notification: {
              icon: "ic_notification",
              color: "#FF6B35", // Squad app orange color
              sound: "default",
              channelId: "hangout_notifications",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
                category: "hangout_notification",
              },
            },
          },
        };
        */
        const message = {
            ...commonPayload,
            topic: topic,
        };
        // Use the unified `send` method
        const response = await admin.messaging().send(message)
            .then((response) => {
            // Response is a message ID string.
            console.log('Successfully sent message:', response);
        })
            .catch((error) => {
            console.log('Error sending message:', error);
        });
        firebase_functions_1.logger.info(`Successfully sent notification to topic ${topic}`, {
            postId: postId,
            messageId: response,
            topic: topic,
        });
    }
    catch (error) {
        firebase_functions_1.logger.error(`Failed to send notification to topic ${topic}:`, {
            postId: postId,
            topic: topic,
            error: error,
            errorMessage: error.message,
            errorCode: error.code,
        });
    }
}
/**
 * Cloud Function to send notification when someone joins a hangout
 */
exports.sendJoinNotification = (0, https_1.onCall)(async (request) => {
    try {
        const { hangoutId, ownerId, joinerName, joinerId } = request.data;
        // Validate required parameters
        if (!hangoutId || !ownerId || !joinerName || !joinerId) {
            firebase_functions_1.logger.error("Missing required parameters for join notification", {
                hangoutId,
                ownerId,
                joinerName,
                joinerId,
            });
            throw new Error("Missing required parameters");
        }
        // Don't notify if the owner joined their own hangout
        if (ownerId === joinerId) {
            firebase_functions_1.logger.info("Skipping notification - owner joined their own hangout", {
                hangoutId,
                ownerId,
            });
            return { success: true, message: "Owner joined own hangout - no notification needed" };
        }
        firebase_functions_1.logger.info("Processing join notification", {
            hangoutId,
            ownerId,
            joinerName,
            joinerId,
        });
        // Get the hangout owner's FCM token
        const ownerDoc = await admin.firestore().collection("users").doc(ownerId).get();
        if (!ownerDoc.exists) {
            firebase_functions_1.logger.error("Hangout owner not found", { ownerId });
            throw new Error("Hangout owner not found");
        }
        const ownerData = ownerDoc.data();
        const fcmToken = ownerData === null || ownerData === void 0 ? void 0 : ownerData.fcmToken;
        if (!fcmToken) {
            firebase_functions_1.logger.warn("Owner does not have FCM token", { ownerId });
            return { success: true, message: "Owner has no FCM token - notification not sent" };
        }
        // Create notification payload
        const message = {
            token: fcmToken,
            notification: {
                body: "Someone joined your plan.",
            },
            data: {
                type: "hangout_join",
                hangoutId: hangoutId,
                joinerName: joinerName,
                joinerId: joinerId,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
                notification: {
                    icon: "ic_notification",
                    color: "#FF6B35",
                    sound: "default",
                    channelId: "hangout_notifications",
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                        badge: 1,
                        category: "hangout_notification",
                    },
                },
            },
        };
        // Send the notification
        const response = await admin.messaging().send(message);
        firebase_functions_1.logger.info("Successfully sent join notification", {
            hangoutId,
            ownerId,
            messageId: response,
        });
        return { success: true, messageId: response };
    }
    catch (error) {
        firebase_functions_1.logger.error("Error sending join notification:", error);
        throw error;
    }
});
/**
 * Cloud Function to send notification when someone leaves a hangout
 */
exports.sendLeaveNotification = (0, https_1.onCall)(async (request) => {
    try {
        const { hangoutId, ownerId, leaverName, leaverId } = request.data;
        // Validate required parameters
        if (!hangoutId || !ownerId || !leaverName || !leaverId) {
            firebase_functions_1.logger.error("Missing required parameters for leave notification", {
                hangoutId,
                ownerId,
                leaverName,
                leaverId,
            });
            throw new Error("Missing required parameters");
        }
        // Don't notify if the owner left their own hangout
        if (ownerId === leaverId) {
            firebase_functions_1.logger.info("Skipping notification - owner left their own hangout", {
                hangoutId,
                ownerId,
            });
            return { success: true, message: "Owner left own hangout - no notification needed" };
        }
        firebase_functions_1.logger.info("Processing leave notification", {
            hangoutId,
            ownerId,
            leaverName,
            leaverId,
        });
        // Get the hangout owner's FCM token
        const ownerDoc = await admin.firestore().collection("users").doc(ownerId).get();
        if (!ownerDoc.exists) {
            firebase_functions_1.logger.error("Hangout owner not found", { ownerId });
            throw new Error("Hangout owner not found");
        }
        const ownerData = ownerDoc.data();
        const fcmToken = ownerData === null || ownerData === void 0 ? void 0 : ownerData.fcmToken;
        if (!fcmToken) {
            firebase_functions_1.logger.warn("Owner does not have FCM token", { ownerId });
            return { success: true, message: "Owner has no FCM token - notification not sent" };
        }
        // Create notification payload
        const message = {
            token: fcmToken,
            notification: {
                body: "Someone left your hangout.",
            },
            data: {
                type: "hangout_leave",
                hangoutId: hangoutId,
                leaverName: leaverName,
                leaverId: leaverId,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
                notification: {
                    icon: "ic_notification",
                    color: "#FF6B35",
                    sound: "default",
                    channelId: "hangout_notifications",
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                        badge: 1,
                        category: "hangout_notification",
                    },
                },
            },
        };
        // Send the notification
        const response = await admin.messaging().send(message);
        firebase_functions_1.logger.info("Successfully sent leave notification", {
            hangoutId,
            ownerId,
            messageId: response,
        });
        return { success: true, messageId: response };
    }
    catch (error) {
        firebase_functions_1.logger.error("Error sending leave notification:", error);
        throw error;
    }
});
/**
 * Cloud Function to send notification when a hangout is updated
 * (description, time, or location changed)
 */
exports.sendHangoutUpdateNotification = (0, https_1.onCall)(async (request) => {
    var _a;
    try {
        const { hangoutId, ownerId, participantIds, changes, oldDescription, oldTime, oldLocation, newDescription, newTime, newLocation, } = request.data;
        // Validate required parameters
        if (!hangoutId || !ownerId || !participantIds || !changes) {
            firebase_functions_1.logger.error("Missing required parameters for hangout update notification", {
                hangoutId,
                ownerId,
                participantIds,
                changes,
            });
            throw new Error("Missing required parameters");
        }
        firebase_functions_1.logger.info("Processing hangout update notification", {
            hangoutId,
            ownerId,
            changes,
            participantCount: participantIds.length,
        });
        // Filter out the owner from participants
        const recipientIds = participantIds.filter((id) => id !== ownerId);
        if (recipientIds.length === 0) {
            firebase_functions_1.logger.info("No recipients to notify (only owner in hangout)", {
                hangoutId,
            });
            return { success: true, message: "No recipients to notify" };
        }
        // Fetch FCM tokens for all recipients
        const tokens = [];
        for (const userId of recipientIds) {
            try {
                const userDoc = await admin.firestore().collection("users").doc(userId).get();
                if (userDoc.exists) {
                    const fcmToken = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.fcmToken;
                    if (fcmToken) {
                        tokens.push(fcmToken);
                    }
                }
            }
            catch (error) {
                firebase_functions_1.logger.warn(`Failed to get FCM token for user ${userId}:`, error);
                // Continue processing other users
            }
        }
        if (tokens.length === 0) {
            firebase_functions_1.logger.warn("No valid FCM tokens found for recipients", {
                hangoutId,
                recipientCount: recipientIds.length,
            });
            return { success: true, message: "No valid FCM tokens found" };
        }
        firebase_functions_1.logger.info("Sending hangout update notifications", {
            hangoutId,
            tokenCount: tokens.length,
            changes,
        });
        // Create notification message
        const message = {
            notification: {
                body: "A plan you're in was updated. Tap to view.",
            },
            data: {
                type: "hangout_update",
                hangoutId: hangoutId,
                hangout_id: hangoutId,
                changes: JSON.stringify(changes),
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
                notification: {
                    icon: "ic_notification",
                    color: "#FF6B35",
                    sound: "default",
                    channelId: "hangout_notifications",
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                        badge: 1,
                        category: "hangout_notification",
                    },
                },
            },
        };
        // Send multicast notification to all tokens
        const response = await admin.messaging().sendEachForMulticast({
            tokens: tokens,
            ...message,
        });
        firebase_functions_1.logger.info("Successfully sent hangout update notifications", {
            hangoutId,
            successCount: response.successCount,
            failureCount: response.failureCount,
            totalTokens: tokens.length,
        });
        // Log any failures
        if (response.failureCount > 0) {
            response.responses.forEach((resp, idx) => {
                var _a, _b;
                if (!resp.success) {
                    firebase_functions_1.logger.warn(`Failed to send notification to token ${idx}`, {
                        error: (_a = resp.error) === null || _a === void 0 ? void 0 : _a.message,
                        errorCode: (_b = resp.error) === null || _b === void 0 ? void 0 : _b.code,
                    });
                }
            });
        }
        return {
            success: true,
            successCount: response.successCount,
            failureCount: response.failureCount,
            totalTokens: tokens.length,
        };
    }
    catch (error) {
        firebase_functions_1.logger.error("Error sending hangout update notification:", error);
        throw error;
    }
});
//# sourceMappingURL=hangout-notifications.js.map