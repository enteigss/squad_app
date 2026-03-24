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
 * Interface for MatchedGroup data
 */
interface MatchedGroup {
  id: string;
  memberIds: string[];
  status: string;
}

/**
 * Interface for User data with notification preferences
 */
interface User {
  id: string;
  fcmToken?: string;
  hangoutChatNotifications?: {[hangoutId: string]: boolean};
  matchGroupChatNotifications?: {[groupId: string]: boolean};
}

/**
 * Notification context configuration
 */
interface NotificationContext {
  chatRoomId: string;
  messageId: string;
  messageData: ChatMessage;
  notificationType: string;
  prefsField: "hangoutChatNotifications" | "matchGroupChatNotifications";
  dataPayload: {[key: string]: string};
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
    } catch (error) {
      logger.error("Error processing chat notification:", error);
    }
  }
);

/**
 * Cloud Function that triggers when a new chat message is created in a matched group
 * Sends push notifications to members who have notifications enabled
 */
export const matchGroupChatMessageNotifications = onDocumentCreated(
  "matched_groups/{groupId}/messages/{messageId}",
  async (event) => {
    try {
      const messageData = event.data?.data() as ChatMessage;
      const groupId = event.params.groupId;
      const messageId = event.params.messageId;

      if (!messageData) {
        logger.warn(`No data found for message ${messageId} in matched group ${groupId}`);
        return;
      }

      logger.info(`Processing chat message notification for matched group ${groupId}`, {
        messageId: messageId,
        senderId: messageData.senderId,
        senderName: messageData.senderName,
        type: messageData.type,
      });

      if (messageData.type === "system") {
        logger.info(`Skipping notification for system message ${messageId}`);
        return;
      }

      // Get the matched group data
      const groupDoc = await admin.firestore()
        .collection("matched_groups")
        .doc(groupId)
        .get();

      if (!groupDoc.exists) {
        logger.warn(`Matched group ${groupId} not found`);
        return;
      }

      const groupData = groupDoc.data() as MatchedGroup;

      if (groupData.status !== "active") {
        logger.info(`Skipping notifications for non-active matched group ${groupId} (status: ${groupData.status})`);
        return;
      }

      // Get all members except the sender
      const recipientIds = groupData.memberIds.filter(
        (memberId) => memberId !== messageData.senderId
      );

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
    } catch (error) {
      logger.error("Error processing matched group chat notification:", error);
    }
  }
);

/**
 * Shared logic: send chat notifications to a list of recipients
 */
async function sendChatNotifications(
  ctx: NotificationContext,
  recipientIds: string[]
): Promise<void> {
  if (recipientIds.length === 0) {
    logger.info(`No recipients to notify for message ${ctx.messageId}`);
    return;
  }

  logger.info(`Found ${recipientIds.length} potential recipients`, {
    recipientIds: recipientIds,
  });

  const notificationPromises = recipientIds.map((recipientId) =>
    sendNotificationToUser(recipientId, ctx)
  );

  const results = await Promise.allSettled(notificationPromises);

  const successCount = results.filter((r) => r.status === "fulfilled").length;
  const failureCount = results.filter((r) => r.status === "rejected").length;

  logger.info(`Completed processing chat notifications for message ${ctx.messageId}`, {
    chatRoomId: ctx.chatRoomId,
    totalRecipients: recipientIds.length,
    successCount: successCount,
    failureCount: failureCount,
  });
}

/**
 * Send notification to a specific user if they have notifications enabled
 */
async function sendNotificationToUser(
  userId: string,
  ctx: NotificationContext
): Promise<void> {
  let userData: User | undefined;

  try {
    const userDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      logger.warn(`User ${userId} not found`);
      return;
    }

    userData = userDoc.data() as User;

    if (!userData.fcmToken) {
      logger.info(`User ${userId} has no FCM token - skipping notification`);
      return;
    }

    // Check notification preferences - default to true (enabled) if not set
    const notificationPrefs = userData[ctx.prefsField] || {};
    const notificationsEnabled = notificationPrefs[ctx.chatRoomId] ?? true;

    if (!notificationsEnabled) {
      logger.info(`User ${userId} has disabled notifications for ${ctx.chatRoomId}`);
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

    logger.info(`Successfully sent chat notification to user ${userId}`, {
      chatRoomId: ctx.chatRoomId,
      messageId: ctx.messageId,
      responseId: response,
    });
  } catch (error) {
    logger.error(`Failed to send chat notification to user ${userId}:`, {
      chatRoomId: ctx.chatRoomId,
      messageId: ctx.messageId,
      error: error,
      errorMessage: (error as Error).message,
      errorCode: (error as any).code,
      errorDetails: (error as any).details,
      fcmToken: userData?.fcmToken ? `${userData.fcmToken.substring(0, 20)}...` : "none",
    });
    throw error;
  }
}
