# SMS Invite System Setup Guide

This guide will walk you through setting up the complete SMS invite system for your Squad app, including Twilio integration, Firebase Cloud Functions, and mobile web previews.

## Prerequisites

- Firebase project set up
- Flutter development environment
- Node.js 18+ installed
- Firebase CLI installed (`npm install -g firebase-tools`)
- Twilio account

## 1. Twilio Setup

### Create Twilio Account
1. Go to [twilio.com](https://www.twilio.com) and sign up
2. Verify your phone number
3. Navigate to Console → Account → Account SID and Auth Token
4. Save these credentials securely

### Get Phone Number
1. In Twilio Console, go to Phone Numbers → Manage → Buy a number
2. Choose a number that supports SMS
3. Purchase the number (costs vary by region)
4. Save the phone number in E.164 format (e.g., +1234567890)

### Budget Management (Recommended for Startups)
1. Go to Console → Billing → Account Limits
2. Set spending limits to control costs
3. SMS costs typically $0.0075-$0.01 per message in the US

## 2. Firebase Configuration

### Update Firebase Environment Variables
1. In Firebase Console, go to Project Settings → Service accounts
2. Click "Generate new private key" and download the JSON file
3. Go to Functions → Configuration and add these environment variables:

```bash
firebase functions:config:set \
  twilio.account_sid="your_twilio_account_sid" \
  twilio.auth_token="your_twilio_auth_token" \
  twilio.phone_number="your_twilio_phone_number"
```

Or using the Firebase Console:
- `twilio.account_sid`: Your Twilio Account SID
- `twilio.auth_token`: Your Twilio Auth Token  
- `twilio.phone_number`: Your Twilio phone number (e.g., +1234567890)

### Update Project ID in Code
1. Find your Firebase project ID in Firebase Console → Project Settings
2. Update the following files with your project ID:

**functions/src/web-preview.ts** (line ~180):
```typescript
const webUrl = `https://YOUR_PROJECT_ID.web.app/hangout/${hangoutId}?inviter=${inviterId}&src=sms`;
```

**lib/services/invite_service.dart** (line 10):
```dart
static const String _functionsBaseUrl = 'https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net';
```

Replace `YOUR_PROJECT_ID` with your actual Firebase project ID.

## 3. Firebase Functions Deployment

### Install Dependencies
```bash
cd functions
npm install
```

### Build TypeScript
```bash
npm run build
```

### Deploy Functions
```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy specific functions
firebase deploy --only functions:sendSMSInvite
firebase deploy --only functions:hangoutPreview
```

### Verify Deployment
1. Check Firebase Console → Functions
2. Should see `sendSMSInvite` and `hangoutPreview` functions
3. Test functions in the Firebase console if needed

## 4. Firebase Hosting (Web Previews)

### Configure Hosting
Update `firebase.json` to include hosting:
```json
{
  "functions": [...],
  "hosting": {
    "public": "web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "/hangout/**",
        "function": "hangoutPreview"
      },
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

### Deploy Hosting
```bash
firebase deploy --only hosting
```

### Test Web Preview
Visit: `https://YOUR_PROJECT_ID.web.app/hangout/test123?inviter=user456&src=sms`

## 5. Mobile App Configuration

### Update Dependencies
Run in your Flutter project root:
```bash
flutter pub get
```

### Android Permissions
Add to `android/app/src/main/AndroidManifest.xml` (should already be added):
```xml
<uses-permission android:name="android.permission.READ_CONTACTS" />
```

### iOS Permissions
Add to `ios/Runner/Info.plist` (should already be added):
```xml
<key>NSContactsUsageDescription</key>
<string>This app needs access to contacts to send hangout invites to your friends.</string>
```

### Test Deep Linking
#### Android
```bash
adb shell am start \
  -W -a android.intent.action.VIEW \
  -d "squadapp://hangout/test123?inviter=user456" \
  com.example.squad_app
```

#### iOS (Simulator)
```bash
xcrun simctl openurl booted "squadapp://hangout/test123?inviter=user456"
```

## 6. Firestore Security Rules

Deploy the security rules:
```bash
firebase deploy --only firestore:rules
```

## 7. App Store Configuration (Production)

### iOS App Store
1. Update `ios/Runner/Info.plist` with your actual App Store URL:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>your.app.bundle.id</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>squadapp</string>
    </array>
  </dict>
</array>
```

2. Update web preview URLs in `functions/src/web-preview.ts`:
```typescript
const appStoreUrl = "https://apps.apple.com/app/your-app-id";
```

### Google Play Store
1. Update web preview URLs in `functions/src/web-preview.ts`:
```typescript
const playStoreUrl = "https://play.google.com/store/apps/details?id=your.package.name";
```

2. Add intent filters in Android manifest (already configured)

## 8. Testing the Complete Flow

### End-to-End Test
1. **Create a hangout** in the app
2. **Tap "Invite Friends"** in the success dialog
3. **Select "SMS Invite"**
4. **Choose contacts** from your phone
5. **Send invites**
6. **Check recipient's phone** for SMS
7. **Tap the link** in SMS
8. **Verify web preview** loads correctly
9. **Test app redirect** if app is installed

### Test Scenarios
- ✅ SMS delivery to valid numbers
- ✅ Web preview displays hangout details correctly
- ✅ Deep linking opens app (if installed)
- ✅ App store redirect (if app not installed)
- ✅ Error handling for invalid phone numbers
- ✅ Permission handling for contacts

## 9. Monitoring and Analytics

### Firebase Functions Logs
```bash
firebase functions:log
```

### Twilio SMS Logs
1. Go to Twilio Console → Monitor → Logs → Programmable SMS
2. Check message status and delivery reports

### Error Monitoring
1. Enable Firebase Crashlytics for the mobile app
2. Monitor Cloud Functions errors in Firebase Console

## 10. Cost Optimization

### SMS Costs
- US/Canada: ~$0.0075 per SMS
- International: $0.01-$0.05 per SMS
- Set Twilio spending limits for budget control

### Firebase Functions
- Free tier: 2M invocations/month
- Paid: $0.40 per million invocations
- Use environment variables to control feature flags

### Firebase Hosting
- Free tier: 10GB storage, 360MB/day transfer
- Should be sufficient for web previews

## 11. Production Checklist

- [ ] Twilio account verified and phone number purchased
- [ ] Firebase environment variables configured
- [ ] Project IDs updated in all files
- [ ] Cloud Functions deployed and tested
- [ ] Hosting deployed and web previews working
- [ ] Mobile app permissions configured
- [ ] Deep linking tested on both platforms
- [ ] Firestore security rules deployed
- [ ] App Store URLs updated
- [ ] Error monitoring enabled
- [ ] Spending limits configured
- [ ] End-to-end testing completed

## 12. Troubleshooting

### Common Issues

**SMS not sending:**
- Check Twilio credentials in Firebase config
- Verify phone number format (E.164)
- Check Twilio account balance
- Review Firebase Functions logs

**Web preview not loading:**
- Verify Hosting deployment
- Check Firebase project ID in URLs
- Test direct function URL

**Deep linking not working:**
- Verify app scheme configuration
- Test with ADB/Simulator commands
- Check app is properly installed
- Review device URL handling settings

**Contacts permission denied:**
- Check Android/iOS permission configuration
- Test permission flow in app
- Verify manifest/plist entries

### Support Resources
- [Twilio SMS Documentation](https://www.twilio.com/docs/sms)
- [Firebase Functions Guide](https://firebase.google.com/docs/functions)
- [Flutter Deep Linking](https://docs.flutter.dev/development/ui/navigation/deep-linking)
- [Firebase Hosting](https://firebase.google.com/docs/hosting)

## 13. Feature Extensions

Consider these enhancements for future versions:
- Batch SMS sending for large contact lists
- SMS templates for different hangout types
- Unsubscribe link handling
- SMS delivery status tracking
- International phone number validation
- Rich link previews in SMS
- A/B testing for invite messaging