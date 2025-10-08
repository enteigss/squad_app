# Cloud Function: sendHangoutUpdateNotification

✅ **IMPLEMENTED** - This Cloud Function has been created and deployed.

## Function Name
`sendHangoutUpdateNotification`

## Purpose
Send push notifications to all hangout members (except the owner) when any aspect of the hangout is updated (title, description, time, or location).

## Location
`/functions/src/hangout-notifications.ts`

## Input Parameters
```javascript
{
  hangoutId: string,        // The ID of the hangout
  hangoutTitle: string,     // The current title of the hangout
  ownerId: string,          // The ID of the hangout owner (to exclude from notifications)
  participantIds: string[], // Array of all participant IDs
  changes: string[],        // Array of what changed: ['title', 'description', 'time', 'location']

  // Old values (only provided if changed)
  oldTitle: string?,        // Old title if title changed
  oldDescription: string?,  // Old description if description changed
  oldTime: string?,         // ISO 8601 string of old scheduled time if time changed
  oldLocation: string?,     // Old location if location changed

  // New values (only provided if changed)
  newTitle: string?,        // New title if title changed
  newDescription: string?,  // New description if description changed
  newTime: string?,         // ISO 8601 string of new scheduled time if time changed
  newLocation: string?      // New location if location changed
}
```

## Implementation Steps

1. **Filter Recipients**: Remove the owner from the participant list
2. **Fetch FCM Tokens**: Get FCM tokens for remaining participants from Firestore users collection
3. **Build Notification Message**: Create message based on what changed
4. **Send Notifications**: Send FCM notifications to all participants

## Notification Format

### Title
```
"Hangout Updated"
```

### Body (Dynamic based on changes)
Examples:
- Single change: `"{hangoutTitle}" time has been updated`
- Multiple changes: `"{hangoutTitle}" has been updated (title, time)`
- All changes: `"{hangoutTitle}" details have been updated`

### Data Payload
```javascript
{
  type: 'hangout_update',
  hangoutId: hangoutId,
  hangout_id: hangoutId,  // Alternative key for compatibility
  click_action: 'FLUTTER_NOTIFICATION_CLICK'
}
```

## Example Implementation (Node.js)

```javascript
exports.sendHangoutUpdateNotification = functions.https.onCall(async (data, context) => {
  const {
    hangoutId,
    hangoutTitle,
    ownerId,
    participantIds,
    changes,
    oldTitle,
    oldDescription,
    oldTime,
    oldLocation,
    newTitle,
    newDescription,
    newTime,
    newLocation
  } = data;

  // Filter out the owner
  const recipientIds = participantIds.filter(id => id !== ownerId);

  if (recipientIds.length === 0) {
    return { success: true, message: 'No recipients to notify' };
  }

  // Fetch FCM tokens
  const tokens = [];
  for (const userId of recipientIds) {
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (fcmToken) {
      tokens.push(fcmToken);
    }
  }

  if (tokens.length === 0) {
    return { success: true, message: 'No valid FCM tokens found' };
  }

  // Build notification body based on changes
  let bodyText;
  if (changes.length === 1) {
    const change = changes[0];
    bodyText = `"${hangoutTitle}" ${change} has been updated`;
  } else if (changes.length === 2) {
    bodyText = `"${hangoutTitle}" ${changes[0]} and ${changes[1]} have been updated`;
  } else if (changes.length > 2) {
    bodyText = `"${hangoutTitle}" details have been updated`;
  } else {
    bodyText = `"${hangoutTitle}" has been updated`;
  }

  // Send notifications
  const message = {
    notification: {
      title: 'Hangout Updated',
      body: bodyText
    },
    data: {
      type: 'hangout_update',
      hangoutId: hangoutId,
      hangout_id: hangoutId,
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    }
  };

  const response = await admin.messaging().sendMulticast({
    tokens: tokens,
    ...message
  });

  return {
    success: true,
    successCount: response.successCount,
    failureCount: response.failureCount
  };
});
```

## Navigation Behavior

When users tap the notification, they should be directed to the hangout screen (group members view) so they can see the updated hangout details.

## Error Handling

- Gracefully handle missing FCM tokens
- Don't throw errors that would block the update operation in the app
- Log errors for debugging but return success to avoid breaking the flow

## Change Tracking

The `changes` array indicates which fields were modified:
- `'title'` - Hangout title changed
- `'description'` - Hangout description changed
- `'time'` - Scheduled time changed
- `'location'` - Location changed

Use this array to build appropriate notification messages that inform users specifically what changed.

## Deployment

To deploy this function to Firebase:

```bash
cd functions
npm run build
firebase deploy --only functions:sendHangoutUpdateNotification
```

Or deploy all functions:

```bash
cd functions
npm run build
firebase deploy --only functions
```

## Testing

You can test this function using the Firebase Emulator Suite or by updating a hangout in the app and checking if notifications are sent to all participants.
