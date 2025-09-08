import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions";
import * as admin from "firebase-admin";

// Interface for Post data structure matching the Flutter model
interface Post {
  id: string;
  title: string;
  description: string;
  authorId: string;
  authorName: string;
  genderPreferences: string[];
  deleted?: boolean;
  isLocked?: boolean;
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

      logger.info(`Processing new hangout notification for post ${postId}`, {
        title: postData.title,
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
  const maxDescriptionLength = 100;
  const descriptionPreview = postData.description.length > maxDescriptionLength
    ? `${postData.description.substring(0, maxDescriptionLength)}...`
    : postData.description;

  // This function returns a simple object with `notification` and `data` keys.
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
      title: postData.title,
    });

    // Construct the full message payload for the unified `send` method
    const message = {
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

    // Use the unified `send` method
    const response = await admin.messaging().send(message);
    
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