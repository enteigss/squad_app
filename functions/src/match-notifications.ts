import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Interface for MatchedGroup data structure
 */
interface MatchedGroup {
  id: string;
  name: string;
  memberIds: string[];
  matchId?: string;
  sharedInterests?: string;
  activitySuggestion?: string;
  createdAt: admin.firestore.Timestamp;
  status: string;
}

/**
 * Interface for User data
 */
interface User {
  id: string;
  fcmToken?: string;
  displayName?: string;
}

/**
 * Cloud Function that triggers when a new matched group is created.
 * Sends push notifications to all members letting them know they've been matched.
 */
export const matchNotifications = onDocumentCreated(
  "matched_groups/{groupId}",
  async (event) => {
    try {
      const groupData = event.data?.data() as MatchedGroup;
      const groupId = event.params.groupId;

      if (!groupData) {
        logger.warn(`No data found for matched group ${groupId}`);
        return;
      }

      logger.info(`Processing match notification for group ${groupId}`, {
        groupId: groupId,
        memberIds: groupData.memberIds,
        memberCount: groupData.memberIds.length,
      });

      // Get all members to notify
      const memberIds = groupData.memberIds;

      if (!memberIds || memberIds.length === 0) {
        logger.warn(`No members found in matched group ${groupId}`);
        return;
      }

      logger.info(`Found ${memberIds.length} members to notify`, {
        memberIds: memberIds,
      });

      // Send notifications to each member
      const notificationPromises = memberIds.map((memberId) =>
        sendMatchNotificationToUser(memberId, groupId, groupData)
      );

      const results = await Promise.allSettled(notificationPromises);

      // Count successes and failures
      const successCount = results.filter((r) => r.status === "fulfilled").length;
      const failureCount = results.filter((r) => r.status === "rejected").length;

      logger.info(`Completed processing match notifications for group ${groupId}`, {
        groupId: groupId,
        totalMembers: memberIds.length,
        successCount: successCount,
        failureCount: failureCount,
      });
    } catch (error) {
      logger.error("Error processing match notification:", error);
      // Don't rethrow - we don't want to fail group creation if notifications fail
    }
  }
);

/**
 * Send match notification to a specific user
 */
async function sendMatchNotificationToUser(
  userId: string,
  groupId: string,
  groupData: MatchedGroup
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

    logger.info(`Successfully sent match notification to user ${userId}`, {
      groupId: groupId,
      responseId: response,
    });
  } catch (error) {
    logger.error(`Failed to send match notification to user ${userId}:`, {
      groupId: groupId,
      error: error,
      errorMessage: (error as Error).message,
      errorCode: (error as any).code,
      fcmToken: userData?.fcmToken ? `${userData.fcmToken.substring(0, 20)}...` : "none",
    });
    // Re-throw to mark this promise as rejected
    throw error;
  }
}
