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
exports.hangoutNotifications = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firebase_functions_1 = require("firebase-functions");
const admin = __importStar(require("firebase-admin"));
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
        firebase_functions_1.logger.info(`Processing new hangout notification for post ${postId}`, {
            title: postData.title,
            authorName: postData.authorName,
            genderPreferences: postData.genderPreferences,
        });
        // Determine which topics to send notifications to
        const topics = determineNotificationTopics(postData.genderPreferences);
        if (topics.length === 0) {
            firebase_functions_1.logger.warn(`No topics determined for post ${postId} with preferences:`, postData.genderPreferences);
            return;
        }
        // Create notification payload
        const notification = createNotificationPayload(postData);
        // Send notifications to each topic
        const promises = topics.map((topic) => sendNotificationToTopic(topic, notification, postData, postId));
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
    const topics = [];
    // Handle different gender preference scenarios
    for (const preference of genderPreferences) {
        switch (preference) {
            case "Anyone":
                topics.push("new_hangouts_bu_anyone");
                break;
            case "Men only":
                topics.push("new_hangouts_bu_men");
                break;
            case "Women only":
                topics.push("new_hangouts_bu_women");
                break;
            case "Non-binary only":
                // Include non-binary users in the "anyone" topic for inclusivity
                topics.push("new_hangouts_bu_anyone");
                break;
            default:
                firebase_functions_1.logger.warn(`Unknown gender preference: ${preference}`);
                break;
        }
    }
    // Remove duplicates in case multiple preferences map to the same topic
    return [...new Set(topics)];
}
/**
 * Creates the notification payload with hangout details
 */
function createNotificationPayload(postData) {
    // Truncate description for notification preview
    const maxDescriptionLength = 100;
    const descriptionPreview = postData.description.length > maxDescriptionLength
        ? `${postData.description.substring(0, maxDescriptionLength)}...`
        : postData.description;
    return {
        notification: {
            title: `New Hangout: ${postData.title}`,
            body: `by ${postData.authorName} - ${descriptionPreview}`,
        },
        data: {
            type: "new_hangout",
            hangout_id: postData.id,
            hangout_title: postData.title,
            author_name: postData.authorName,
            author_id: postData.authorId,
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
}
/**
 * Sends notification to a specific FCM topic
 */
async function sendNotificationToTopic(topic, notification, postData, postId) {
    try {
        firebase_functions_1.logger.info(`Sending notification to topic: ${topic}`, {
            postId: postId,
            title: postData.title,
        });
        const message = {
            ...notification,
            topic: topic,
        };
        const response = await admin.messaging().send(message);
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
        });
        // Don't rethrow - we want to continue trying other topics
    }
}
//# sourceMappingURL=hangout-notifications.js.map