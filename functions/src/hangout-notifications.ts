import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onCall} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";
import * as admin from "firebase-admin";

// Interface for Post data structure matching the Flutter model
interface Post {
  id: string;
  activity?: string;
  customActivity?: string;
  location?: string;
  authorId: string;
  authorName: string;
  genderPreferences: string[];
  deleted?: boolean;
  isLocked?: boolean;
}

/**
 * Helper function to format activity text for notifications
 * Returns format: "{activity} at {location}" or just "{activity}" or just "{location}"
 */
function formatActivityText(post: Post): string {
  let text = "";

  // Get activity name
  if (post.activity === "other" && post.customActivity) {
    text = post.customActivity;
  } else if (post.activity) {
    const activityMap: {[key: string]: string} = {
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
export const hangoutNotifications = onDocumentCreated(
  "posts/{postId}",
  async (event) => {
    try {
      const postData = event.data?.data() as Post;
      const postId = event.params.postId;

      if (!postData) {
        logger.warn(`No data found for post ${postId}`);
        return;
      }

      // Skip notifications for deleted or locked posts
      if (postData.deleted || postData.isLocked) {
        logger.info(`Skipping notifications for deleted/locked post ${postId}`);
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
     
      logger.info(`Processing new hangout notification for post ${postId}`, {
        activity: postData.activity,
        location: postData.location,
        authorName: postData.authorName,
        genderPreferences: postData.genderPreferences,
      });

      // Determine which topics to send notifications to
      const topics = determineNotificationTopics(postData.genderPreferences);

      if (topics.length === 0) {
        logger.warn(`No topics determined for post ${postId} with preferences:`, 
          postData.genderPreferences);
        return;
      }

      // The platform-specific payloads are now created separately
      const notificationPayload = createNotificationBody(postData);

      // Send notifications to each topic
      const promises = topics.map((topic) => 
        sendNotificationToTopic(topic, notificationPayload, postData, postId)
      );

      await Promise.allSettled(promises);

      logger.info(`Completed processing notifications for post ${postId}`, {
        topics: topics,
        topicCount: topics.length,
      });
    } catch (error) {
      logger.error("Error processing hangout notification:", error);
      // Don't rethrow - we don't want to fail post creation if notifications fail
    }
  }
);

/**
 * Determines which FCM topics should receive notifications based on gender preferences
 */
function determineNotificationTopics(genderPreferences: string[]): string[] {
  // Your original logic here is correct and can be reused.
  const topics: string[] = [];

  const hasAllGenders = genderPreferences.includes("Men") &&
                       genderPreferences.includes("Women") &&
                       genderPreferences.includes("Non-binary");

  if (hasAllGenders) {
    topics.push("new_hangouts_all_genders");
  } else {
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
          logger.warn(`Unknown gender preference: ${preference}`);
          break;
      }
    }
  }

  return [...new Set(topics)];
}

/**
 * Creates the notification body and data payloads (common for all platforms)
 */
function createNotificationBody(postData: Post) {
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
async function sendNotificationToTopic(
  topic: string,
  commonPayload: any,
  postData: Post,
  postId: string
): Promise<void> {
  try {
    logger.info(`Sending notification to topic: ${topic}`, {
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
    
    logger.info(`Successfully sent notification to topic ${topic}`, {
      postId: postId,
      messageId: response,
      topic: topic,
    });
  } catch (error) {
    logger.error(`Failed to send notification to topic ${topic}:`, {
      postId: postId,
      topic: topic,
      error: error,
      errorMessage: (error as Error).message,
      errorCode: (error as any).code,
    });
  }
}

/**
 * Cloud Function to send notification when someone joins a hangout
 */
export const sendJoinNotification = onCall(async (request) => {
  try {
    const {hangoutId, ownerId, joinerName, joinerId} = request.data;

    // Validate required parameters
    if (!hangoutId || !ownerId || !joinerName || !joinerId) {
      logger.error("Missing required parameters for join notification", {
        hangoutId,
        ownerId,
        joinerName,
        joinerId,
      });
      throw new Error("Missing required parameters");
    }

    // Don't notify if the owner joined their own hangout
    if (ownerId === joinerId) {
      logger.info("Skipping notification - owner joined their own hangout", {
        hangoutId,
        ownerId,
      });
      return {success: true, message: "Owner joined own hangout - no notification needed"};
    }

    logger.info("Processing join notification", {
      hangoutId,
      ownerId,
      joinerName,
      joinerId,
    });

    // Get the hangout owner's FCM token
    const ownerDoc = await admin.firestore().collection("users").doc(ownerId).get();
    
    if (!ownerDoc.exists) {
      logger.error("Hangout owner not found", {ownerId});
      throw new Error("Hangout owner not found");
    }

    const ownerData = ownerDoc.data();
    const fcmToken = ownerData?.fcmToken;

    if (!fcmToken) {
      logger.warn("Owner does not have FCM token", {ownerId});
      return {success: true, message: "Owner has no FCM token - notification not sent"};
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

    logger.info("Successfully sent join notification", {
      hangoutId,
      ownerId,
      messageId: response,
    });

    return {success: true, messageId: response};
  } catch (error) {
    logger.error("Error sending join notification:", error);
    throw error;
  }
});

/**
 * Cloud Function to send notification when someone leaves a hangout
 */
export const sendLeaveNotification = onCall(async (request) => {
  try {
    const {hangoutId, ownerId, leaverName, leaverId} = request.data;

    // Validate required parameters
    if (!hangoutId || !ownerId || !leaverName || !leaverId) {
      logger.error("Missing required parameters for leave notification", {
        hangoutId,
        ownerId,
        leaverName,
        leaverId,
      });
      throw new Error("Missing required parameters");
    }

    // Don't notify if the owner left their own hangout
    if (ownerId === leaverId) {
      logger.info("Skipping notification - owner left their own hangout", {
        hangoutId,
        ownerId,
      });
      return {success: true, message: "Owner left own hangout - no notification needed"};
    }

    logger.info("Processing leave notification", {
      hangoutId,
      ownerId,
      leaverName,
      leaverId,
    });

    // Get the hangout owner's FCM token
    const ownerDoc = await admin.firestore().collection("users").doc(ownerId).get();
    
    if (!ownerDoc.exists) {
      logger.error("Hangout owner not found", {ownerId});
      throw new Error("Hangout owner not found");
    }

    const ownerData = ownerDoc.data();
    const fcmToken = ownerData?.fcmToken;

    if (!fcmToken) {
      logger.warn("Owner does not have FCM token", {ownerId});
      return {success: true, message: "Owner has no FCM token - notification not sent"};
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

    logger.info("Successfully sent leave notification", {
      hangoutId,
      ownerId,
      messageId: response,
    });

    return {success: true, messageId: response};
  } catch (error) {
    logger.error("Error sending leave notification:", error);
    throw error;
  }
});

/**
 * Cloud Function to send notification when a hangout is updated
 * (description, time, or location changed)
 */
export const sendHangoutUpdateNotification = onCall(async (request) => {
  try {
    const {
      hangoutId,
      ownerId,
      participantIds,
      changes,
      oldDescription,
      oldTime,
      oldLocation,
      newDescription,
      newTime,
      newLocation,
    } = request.data;

    // Validate required parameters
    if (!hangoutId || !ownerId || !participantIds || !changes) {
      logger.error("Missing required parameters for hangout update notification", {
        hangoutId,
        ownerId,
        participantIds,
        changes,
      });
      throw new Error("Missing required parameters");
    }

    logger.info("Processing hangout update notification", {
      hangoutId,
      ownerId,
      changes,
      participantCount: participantIds.length,
    });

    // Filter out the owner from participants
    const recipientIds = participantIds.filter((id: string) => id !== ownerId);

    if (recipientIds.length === 0) {
      logger.info("No recipients to notify (only owner in hangout)", {
        hangoutId,
      });
      return {success: true, message: "No recipients to notify"};
    }

    // Fetch FCM tokens for all recipients
    const tokens: string[] = [];
    for (const userId of recipientIds) {
      try {
        const userDoc = await admin.firestore().collection("users").doc(userId).get();

        if (userDoc.exists) {
          const fcmToken = userDoc.data()?.fcmToken;
          if (fcmToken) {
            tokens.push(fcmToken);
          }
        }
      } catch (error) {
        logger.warn(`Failed to get FCM token for user ${userId}:`, error);
        // Continue processing other users
      }
    }

    if (tokens.length === 0) {
      logger.warn("No valid FCM tokens found for recipients", {
        hangoutId,
        recipientCount: recipientIds.length,
      });
      return {success: true, message: "No valid FCM tokens found"};
    }

    logger.info("Sending hangout update notifications", {
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

    logger.info("Successfully sent hangout update notifications", {
      hangoutId,
      successCount: response.successCount,
      failureCount: response.failureCount,
      totalTokens: tokens.length,
    });

    // Log any failures
    if (response.failureCount > 0) {
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          logger.warn(`Failed to send notification to token ${idx}`, {
            error: resp.error?.message,
            errorCode: resp.error?.code,
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
  } catch (error) {
    logger.error("Error sending hangout update notification:", error);
    throw error;
  }
});