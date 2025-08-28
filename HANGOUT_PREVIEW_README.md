# Hangout Preview Page Implementation

This HTML template provides a deep linking preview page for your cloud function that serves hangout invites.

## Template Variables

Replace these placeholders in your cloud function:

### Required Variables
- `{{hangoutTitle}}` - The title/name of the hangout
- `{{hangoutId}}` - Unique identifier for the hangout  
- `{{inviterName}}` - Name of the person who sent the invite
- `{{inviterId}}` - User ID of the inviter
- `{{currentUrl}}` - Current page URL for Open Graph tags

### Beta App URLs
- `{{testflightUrl}}` - Your TestFlight beta invitation link
  - Format: `https://testflight.apple.com/join/YOUR_CODE`
- `{{androidBetaUrl}}` - Your Android beta distribution link
  - Could be Google Play Console beta track or direct APK download

## Features

### Smart Device Detection
- **iOS devices**: Shows "Open in App" + "Join iOS Beta" buttons
- **Android devices**: Shows "Open in App" + "Join Android Beta" buttons  
- **Desktop/Other**: Shows both beta options, hides deep link button

### Deep Linking
- Uses your existing `linkupbu://` scheme
- Passes hangout ID and inviter ID to your Flutter app
- Includes fallback detection for when app isn't installed

### Beta-Specific Design
- Beta badge in header
- Clear messaging about beta status
- Encourages users to help improve the app

## Cloud Function Integration

In your cloud function, load this template and replace variables:

```javascript
// Example Node.js cloud function code
const fs = require('fs');
const template = fs.readFileSync('hangout_preview_template.html', 'utf8');

const html = template
  .replace(/{{hangoutTitle}}/g, hangoutData.title)
  .replace(/{{hangoutId}}/g, hangoutId)
  .replace(/{{inviterName}}/g, inviterData.name)
  .replace(/{{inviterId}}/g, inviterId)
  .replace(/{{currentUrl}}/g, `https://squad-7bc7e.web.app/hangout/${hangoutId}`)
  .replace(/{{testflightUrl}}/g, 'YOUR_TESTFLIGHT_URL')
  .replace(/{{androidBetaUrl}}/g, 'YOUR_ANDROID_BETA_URL');

res.send(html);
```

## Testing

1. **Test deep link**: `linkupbu://hangout/123?inviter=456`
2. **Test on different devices**: iOS, Android, Desktop
3. **Test with/without app installed**
4. **Verify beta links work correctly**

## Customization

### Branding
- Update colors in CSS (currently uses purple/blue theme)
- Change app icon emoji or add actual logo
- Modify fonts and spacing as needed

### Analytics
- Add tracking code in `trackClick()` function
- Integrate with Google Analytics, Firebase Analytics, etc.

### Content
- Modify messaging in footer
- Add more hangout details if available
- Customize button text and styling

## Next Steps

After implementing the preview page:

1. **Test the complete flow** from your Flutter app sharing to preview page
2. **Set up beta distribution** (TestFlight, Play Console)
3. **Update beta URLs** in the template
4. **Test deep linking** with your existing Flutter deep link service
5. **Add analytics** to track conversion rates

Your Flutter app is already configured to handle the deep links - no additional mobile app changes needed!