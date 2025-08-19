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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendSMSInvite = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const logger = __importStar(require("firebase-functions/logger"));
const twilio_1 = __importDefault(require("twilio"));
// Initialize Twilio client when needed
function getTwilioClient() {
    return (0, twilio_1.default)(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
}
exports.sendSMSInvite = (0, https_1.onCall)({ cors: true }, async (request) => {
    var _a;
    try {
        // Verify authentication
        if (!request.auth) {
            throw new Error("Authentication required");
        }
        const { hangoutId, phoneNumbers, inviterName, inviterId } = request.data;
        // Validate input
        if (!hangoutId || !phoneNumbers || !Array.isArray(phoneNumbers) ||
            phoneNumbers.length === 0 || !inviterName || !inviterId) {
            throw new Error("Missing required fields");
        }
        // Verify user is authenticated and matches inviter
        if (request.auth.uid !== inviterId) {
            throw new Error("Unauthorized: User mismatch");
        }
        // Get hangout details from Firestore
        const hangoutRef = admin.firestore().collection("posts").doc(hangoutId);
        const hangoutDoc = await hangoutRef.get();
        if (!hangoutDoc.exists) {
            throw new Error("Hangout not found");
        }
        const hangout = hangoutDoc.data();
        // Verify user is the author of the hangout
        if (hangout.authorId !== inviterId) {
            throw new Error("Unauthorized: Only hangout author can send invites");
        }
        // Format date/time
        let dateTimeStr = "soon";
        if (hangout.scheduledTime) {
            const date = hangout.scheduledTime.toDate();
            const now = new Date();
            const isToday = date.toDateString() === now.toDateString();
            const isTomorrow = date.toDateString() ===
                new Date(now.getTime() + 24 * 60 * 60 * 1000).toDateString();
            if (isToday) {
                dateTimeStr = `today at ${date.toLocaleTimeString("en-US", {
                    hour: "numeric",
                    minute: "2-digit",
                    hour12: true,
                })}`;
            }
            else if (isTomorrow) {
                dateTimeStr = `tomorrow at ${date.toLocaleTimeString("en-US", {
                    hour: "numeric",
                    minute: "2-digit",
                    hour12: true,
                })}`;
            }
            else {
                dateTimeStr = `${date.toLocaleDateString("en-US", {
                    month: "short",
                    day: "numeric",
                })} at ${date.toLocaleTimeString("en-US", {
                    hour: "numeric",
                    minute: "2-digit",
                    hour12: true,
                })}`;
            }
        }
        // Create invite link with project ID
        const projectId = process.env.GCLOUD_PROJECT || process.env.FIREBASE_CONFIG;
        const webUrl = `https://${projectId}.web.app/hangout/${hangoutId}?inviter=${inviterId}&src=sms`;
        // Format location
        const location = hangout.location || "TBD";
        // Count current participants
        const participantCount = ((_a = hangout.participantIds) === null || _a === void 0 ? void 0 : _a.length) || 1;
        // Create SMS message
        const smsMessage = `Hey! ${inviterName} invited you to "${hangout.title}" ${dateTimeStr} at ${location}. ${participantCount} people going. Join: ${webUrl}`;
        const results = {
            success: true,
            successfulInvites: 0,
            failedInvites: 0,
            errors: [],
        };
        // Send SMS to each phone number
        const sendPromises = phoneNumbers.map(async (phoneNumber) => {
            try {
                // Clean phone number (remove spaces, dashes, etc.)
                const cleanedNumber = phoneNumber.replace(/\D/g, "");
                // Add +1 if it's a 10-digit US number
                const formattedNumber = cleanedNumber.length === 10 ?
                    `+1${cleanedNumber}` : `+${cleanedNumber}`;
                const twilioClient = getTwilioClient();
                await twilioClient.messages.create({
                    body: smsMessage,
                    from: process.env.TWILIO_PHONE_NUMBER,
                    to: formattedNumber,
                });
                results.successfulInvites++;
                // Log successful invite
                logger.info("SMS invite sent successfully", {
                    hangoutId,
                    inviterId,
                    phoneNumber: formattedNumber,
                });
                // Store invite record in Firestore
                await admin.firestore().collection("sms_invites").add({
                    hangoutId,
                    inviterId,
                    inviterName,
                    phoneNumber: formattedNumber,
                    sentAt: admin.firestore.FieldValue.serverTimestamp(),
                    status: "sent",
                });
            }
            catch (error) {
                results.failedInvites++;
                const errorMessage = error instanceof Error ? error.message : "Unknown error";
                results.errors.push(`${phoneNumber}: ${errorMessage}`);
                logger.error("Failed to send SMS invite", {
                    hangoutId,
                    inviterId,
                    phoneNumber,
                    error: errorMessage,
                });
                // Store failed invite record
                await admin.firestore().collection("sms_invites").add({
                    hangoutId,
                    inviterId,
                    inviterName,
                    phoneNumber,
                    sentAt: admin.firestore.FieldValue.serverTimestamp(),
                    status: "failed",
                    error: errorMessage,
                });
            }
        });
        await Promise.all(sendPromises);
        // Update results
        if (results.failedInvites > 0 && results.successfulInvites === 0) {
            results.success = false;
        }
        logger.info("SMS invite batch completed", {
            hangoutId,
            inviterId,
            totalNumbers: phoneNumbers.length,
            successful: results.successfulInvites,
            failed: results.failedInvites,
        });
        return results;
    }
    catch (error) {
        const errorMessage = error instanceof Error ? error.message : "Unknown error";
        logger.error("SMS invite function error", { error: errorMessage });
        return {
            success: false,
            successfulInvites: 0,
            failedInvites: 0,
            errors: [errorMessage],
        };
    }
});
//# sourceMappingURL=sms-invites.js.map