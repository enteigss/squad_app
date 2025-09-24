import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();

// For cost control
setGlobalOptions({maxInstances: 10});

// SMS Invite Functions
export {sendSMSInvite} from "./sms-invites";

// Web Preview Functions  
export {hangoutPreview} from "./web-preview";

// App Invite Functions
export {appPreview} from "./app-preview";

// Hangout Notification Functions
export {hangoutNotifications, sendJoinNotification, sendLeaveNotification} from "./hangout-notifications";

// Report Submission Functions
export {submitReport} from "./report-submissions";

// Email Verification Functions
export {sendVerificationEmail, validateVerificationCode} from "./email-verification";

// Account Deletion Functions
export {deleteUserAccount} from "./account-deletion";

// Health check endpoint
export const healthCheck = onRequest((req, res) => {
  res.json({
    status: "healthy",
    timestamp: new Date().toISOString(),
    service: "squad-app-functions",
  });
});