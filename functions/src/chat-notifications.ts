import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Interface for chat message data structure
 */
interface ChatMessage {
  id: string;
  postId: string;
  senderId: string;
  senderName: string;
  senderPhotoUrl?: string;
  content: string;
  type: string; // 'text', 'image', 'system'
  timestamp: admin.firestore.Timestamp;
  readBy: string[];
}

/**
 * Interface for Post data
 */
interface Post {
  id: string;
  participantIds: string[];
  deleted?: boolean;
  isLocked?: boolean;
}

/**
 * Interface for User data with notification preferences
 */
interface User {
  id: string;
  fcmToken?: string;
  hangoutChatNotifications?: {[hangoutId: string]: boolean};
}

/**
 * Cloud Function that triggers when a new chat message is created in a hangout
 * Sends push notifications to participants who have notifications enabled
 */
export const chatMessageNotifications = onDocumentCreated(
  "posts/{postId}/chat/{messageId}",
  async (event) => {
    try {
      const messageData = event.data?.data() as ChatMessage;
      const postId = event.params.postId;
      const messageId = event.params.messageId;

      if (!messageData) {
        logger.warn(`No data found for message ${messageId} in post ${postId}`);
        return;
      }

      logger.info(`Processing chat message notification for post ${postId}`, {
        messageId: messageId,
        senderId: messageData.senderId,
        senderName: messageData.senderName,
        type: messageData.type,
      });

      // Skip system messages - they don't need notifications
      if (messageData.type === "system") {
        logger.info(`Skipping notification for system message ${messageId}`);
        return;
      }

      // Get the post/hangout data
      const postDoc = await admin.firestore()
        .collection("posts")
        .doc(postId)
        .get();

      if (!postDoc.exists) {
        logger.warn(`Post ${postId} not found`);
        return;
      }

      const postData = postDoc.data() as Post;

      // Skip notifications for deleted or locked posts
      if (postData.deleted || postData.isLocked) {
        logger.info(`Skipping notifications for deleted/locked post ${postId}`);
        return;
      }

      // Get all participants except the sender
      const recipientIds = postData.participantIds.filter(
        (participantId) => participantId !== messageData.senderId
      );

      if (recipientIds.length === 0) {
        logger.info(`No recipients to notify for message ${messageId}`);
        return;
      }

      logger.info(`Found ${recipientIds.length} potential recipients`, {
        recipientIds: recipientIds,
      });

      // Send notifications to each recipient
      const notificationPromises = recipientIds.map((recipientId) =>
        sendNotificationToUser(
          recipientId,
          postId,
          messageData,
          messageId
        )
      );

      const results = await Promise.allSettled(notificationPromises);

      // Count successes and failures
      const successCount = results.filter((r) => r.status === "fulfilled").length;
      const failureCount = results.filter((r) => r.status === "rejected").length;

      logger.info(`Completed processing chat notifications for message ${messageId}`, {
        postId: postId,
        totalRecipients: recipientIds.length,
        successCount: successCount,
        failureCount: failureCount,
      });
    } catch (error) {
      logger.error("Error processing chat notification:", error);
      // Don't rethrow - we don't want to fail message creation if notifications fail
    }
  }
);

/**
 * Send notification to a specific user if they have notifications enabled
 */
async function sendNotificationToUser(
  userId: string,
  postId: string,
  messageData: ChatMessage,
  messageId: string
): Promise<void> {
  let userData: User | undefined;

  try {
    // Get user document
    const userDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      logger.warn(`User ${userId} not found`);
      return;
    }

    userData = userDoc.data() as User;

    // Check if user has FCM token
    if (!userData.fcmToken) {
      logger.info(`User ${userId} has no FCM token - skipping notification`);
      return;
    }

    // Check notification preferences - default to true (enabled) if not set
    const notificationPrefs = userData.hangoutChatNotifications || {};
    const notificationsEnabled = notificationPrefs[postId] ?? true;

    if (!notificationsEnabled) {
      logger.info(`User ${userId} has disabled notifications for hangout ${postId}`);
      return;
    }

    // Create notification payload
    const maxContentLength = 100;
    const contentPreview = messageData.content.length > maxContentLength
      ? `${messageData.content.substring(0, maxContentLength)}...`
      : messageData.content;

    const message = {
      token: userData.fcmToken,
      notification: {
        title: `${messageData.senderName}`,
        body: contentPreview,
      },
      data: {
        type: "chat_message",
        postId: postId,
        messageId: messageId,
        senderId: messageData.senderId,
        senderName: messageData.senderName,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
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

    // Send the notification
    const response = await admin.messaging().send(message);

    logger.info(`Successfully sent chat notification to user ${userId}`, {
      postId: postId,
      messageId: messageId,
      responseId: response,
    });
  } catch (error) {
    logger.error(`Failed to send chat notification to user ${userId}:`, {
      postId: postId,
      messageId: messageId,
      error: error,
      errorMessage: (error as Error).message,
      errorCode: (error as any).code,
      errorDetails: (error as any).details,
      fcmToken: userData?.fcmToken ? `${userData.fcmToken.substring(0, 20)}...` : "none",
    });
    // Re-throw to mark this promise as rejected
    throw error;
  }
}
