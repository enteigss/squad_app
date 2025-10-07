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
exports.healthCheck = exports.deleteUserAccount = exports.validateVerificationCode = exports.sendVerificationEmail = exports.submitReport = exports.chatMessageNotifications = exports.sendLeaveNotification = exports.sendJoinNotification = exports.hangoutNotifications = exports.appPreview = exports.hangoutPreview = exports.sendSMSInvite = void 0;
const firebase_functions_1 = require("firebase-functions");
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
// Initialize Firebase Admin
admin.initializeApp();
// For cost control
(0, firebase_functions_1.setGlobalOptions)({ maxInstances: 10 });
// SMS Invite Functions
var sms_invites_1 = require("./sms-invites");
Object.defineProperty(exports, "sendSMSInvite", { enumerable: true, get: function () { return sms_invites_1.sendSMSInvite; } });
// Web Preview Functions  
var web_preview_1 = require("./web-preview");
Object.defineProperty(exports, "hangoutPreview", { enumerable: true, get: function () { return web_preview_1.hangoutPreview; } });
// App Invite Functions
var app_preview_1 = require("./app-preview");
Object.defineProperty(exports, "appPreview", { enumerable: true, get: function () { return app_preview_1.appPreview; } });
// Hangout Notification Functions
var hangout_notifications_1 = require("./hangout-notifications");
Object.defineProperty(exports, "hangoutNotifications", { enumerable: true, get: function () { return hangout_notifications_1.hangoutNotifications; } });
Object.defineProperty(exports, "sendJoinNotification", { enumerable: true, get: function () { return hangout_notifications_1.sendJoinNotification; } });
Object.defineProperty(exports, "sendLeaveNotification", { enumerable: true, get: function () { return hangout_notifications_1.sendLeaveNotification; } });
// Chat Notification Functions
var chat_notifications_1 = require("./chat-notifications");
Object.defineProperty(exports, "chatMessageNotifications", { enumerable: true, get: function () { return chat_notifications_1.chatMessageNotifications; } });
// Report Submission Functions
var report_submissions_1 = require("./report-submissions");
Object.defineProperty(exports, "submitReport", { enumerable: true, get: function () { return report_submissions_1.submitReport; } });
// Email Verification Functions
var email_verification_1 = require("./email-verification");
Object.defineProperty(exports, "sendVerificationEmail", { enumerable: true, get: function () { return email_verification_1.sendVerificationEmail; } });
Object.defineProperty(exports, "validateVerificationCode", { enumerable: true, get: function () { return email_verification_1.validateVerificationCode; } });
// Account Deletion Functions
var account_deletion_1 = require("./account-deletion");
Object.defineProperty(exports, "deleteUserAccount", { enumerable: true, get: function () { return account_deletion_1.deleteUserAccount; } });
// Health check endpoint
exports.healthCheck = (0, https_1.onRequest)((req, res) => {
    res.json({
        status: "healthy",
        timestamp: new Date().toISOString(),
        service: "squad-app-functions",
    });
});
//# sourceMappingURL=index.js.map