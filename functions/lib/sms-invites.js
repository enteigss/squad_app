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
/**
 * Helper function to format activity text for SMS messages
 * Returns format: "{activity} at {location}" or just "{activity}" or just "{location}"
 */
function formatActivityText(hangout) {
    let text = "";
    // Get activity name
    if (hangout.activity === "other" && hangout.customActivity) {
        text = hangout.customActivity;
    }
    else if (hangout.activity) {
        const activityMap = {
            "diningHall": "Eating",
            "studying": "Studying",
            "walking": "Walking",
            "fitRec": "Working out",
            "chilling": "Chilling",
            "other": "",
        };
        text = activityMap[hangout.activity] || "";
    }
    // Add location
    if (hangout.location) {
        text = text ? `${text} at ${hangout.location}` : hangout.location;
    }
    // Fallback if no activity or location
    return text || "a hangout";
}
exports.sendSMSInvite = (0, https_1.onCall)({ cors: true }, async (request) => {
    var _a, _b;
    logger.info("🚀 SMS Invite Function - Starting execution");
    try {
        logger.info("🔐 SMS Invite Function - Checking authentication");
        // Verify authentication
        if (!request.auth) {
            logger.error("❌ SMS Invite Function - No authentication provided");
            throw new Error("Authentication required");
        }
        logger.info(`✅ SMS Invite Function - User authenticated: ${request.auth.uid}`);
        const { hangoutId, phoneNumbers, inviterName, inviterId } = request.data;
        logger.info("📋 SMS Invite Function - Request data received:", {
            hangoutId,
            phoneNumbers,
            inviterName,
            inviterId,
            phoneNumberCount: (phoneNumbers === null || phoneNumbers === void 0 ? void 0 : phoneNumbers.length) || 0,
        });
        // Validate input
        logger.info("✅ SMS Invite Function - Validating input parameters");
        if (!hangoutId || !phoneNumbers || !Array.isArray(phoneNumbers) ||
            phoneNumbers.length === 0 || !inviterName || !inviterId) {
            logger.error("❌ SMS Invite Function - Missing required fields:", {
                hasHangoutId: !!hangoutId,
                hasPhoneNumbers: !!phoneNumbers,
                isPhoneNumbersArray: Array.isArray(phoneNumbers),
                phoneNumbersLength: (phoneNumbers === null || phoneNumbers === void 0 ? void 0 : phoneNumbers.length) || 0,
                hasInviterName: !!inviterName,
                hasInviterId: !!inviterId,
            });
            throw new Error("Missing required fields");
        }
        logger.info("✅ SMS Invite Function - Input validation passed");
        // Verify user is authenticated and matches inviter
        logger.info("🔍 SMS Invite Function - Verifying user authorization");
        if (request.auth.uid !== inviterId) {
            logger.error("❌ SMS Invite Function - User mismatch:", {
                authUid: request.auth.uid,
                inviterId: inviterId,
            });
            throw new Error("Unauthorized: User mismatch");
        }
        logger.info("✅ SMS Invite Function - User authorization verified");
        // Get hangout details from Firestore
        logger.info("📄 SMS Invite Function - Fetching hangout details from Firestore");
        const hangoutRef = admin.firestore().collection("posts").doc(hangoutId);
        const hangoutDoc = await hangoutRef.get();
        if (!hangoutDoc.exists) {
            logger.error("❌ SMS Invite Function - Hangout not found:", { hangoutId });
            throw new Error("Hangout not found");
        }
        logger.info("✅ SMS Invite Function - Hangout document found");
        const hangout = hangoutDoc.data();
        logger.info("📋 SMS Invite Function - Hangout data:", {
            activity: hangout.activity,
            customActivity: hangout.customActivity,
            authorId: hangout.authorId,
            location: hangout.location,
            hasScheduledTime: !!hangout.scheduledTime,
            participantCount: ((_a = hangout.participantIds) === null || _a === void 0 ? void 0 : _a.length) || 0,
        });
        // Verify user is the author of the hangout
        logger.info("🔍 SMS Invite Function - Verifying hangout authorship");
        if (hangout.authorId !== inviterId) {
            logger.error("❌ SMS Invite Function - Unauthorized: Not hangout author:", {
                hangoutAuthorId: hangout.authorId,
                inviterId: inviterId,
            });
            throw new Error("Unauthorized: Only hangout author can send invites");
        }
        logger.info("✅ SMS Invite Function - Hangout authorship verified");
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
        logger.info("🔗 SMS Invite Function - Creating invite link");
        const projectId = process.env.GCLOUD_PROJECT || process.env.FIREBASE_CONFIG;
        const webUrl = `https://${projectId}.web.app/hangout/${hangoutId}?inviter=${inviterId}&src=sms`;
        logger.info("📋 SMS Invite Function - Invite link created:", {
            projectId,
            webUrl,
        });
        // Format location
        const location = hangout.location || "TBD";
        // Count current participants
        const participantCount = ((_b = hangout.participantIds) === null || _b === void 0 ? void 0 : _b.length) || 1;
        // Format hangout title
        const hangoutTitle = formatActivityText(hangout);
        // Create SMS message
        const smsMessage = `Hey! ${inviterName} invited you to "${hangoutTitle}" ${dateTimeStr}. ${participantCount} people going. Join: ${webUrl}`;
        logger.info("💬 SMS Invite Function - SMS message created:", {
            messageLength: smsMessage.length,
            message: smsMessage,
        });
        const results = {
            success: true,
            successfulInvites: 0,
            failedInvites: 0,
            errors: [],
        };
        logger.info("📊 SMS Invite Function - Starting SMS sending process for phones:", phoneNumbers);
        // Send SMS to each phone number
        const sendPromises = phoneNumbers.map(async (phoneNumber, index) => {
            logger.info(`📱 SMS Invite Function - Processing phone ${index + 1}/${phoneNumbers.length}: ${phoneNumber}`);
            try {
                // Clean phone number (remove spaces, dashes, etc.)
                const cleanedNumber = phoneNumber.replace(/\D/g, "");
                logger.info(`🧹 SMS Invite Function - Cleaned number: ${cleanedNumber}`);
                // Add +1 if it's a 10-digit US number
                const formattedNumber = cleanedNumber.length === 10 ?
                    `+1${cleanedNumber}` : `+${cleanedNumber}`;
                logger.info(`📞 SMS Invite Function - Formatted number: ${formattedNumber}`);
                // Check Twilio environment variables
                logger.info("🔧 SMS Invite Function - Checking Twilio config:", {
                    hasTwilioSid: !!process.env.TWILIO_ACCOUNT_SID,
                    hasTwilioToken: !!process.env.TWILIO_AUTH_TOKEN,
                    hasTwilioPhone: !!process.env.TWILIO_PHONE_NUMBER,
                    twilioPhone: process.env.TWILIO_PHONE_NUMBER,
                });
                logger.info("📤 SMS Invite Function - Sending SMS via Twilio");
                const twilioClient = getTwilioClient();
                const messageParams = {
                    body: smsMessage,
                    from: process.env.TWILIO_PHONE_NUMBER,
                    to: formattedNumber,
                };
                logger.info("📋 SMS Invite Function - Twilio message params:", messageParams);
                const twilioResponse = await twilioClient.messages.create(messageParams);
                logger.info("✅ SMS Invite Function - Twilio response:", {
                    sid: twilioResponse.sid,
                    status: twilioResponse.status,
                    dateCreated: twilioResponse.dateCreated,
                });
                results.successfulInvites++;
                // Log successful invite
                logger.info("✅ SMS invite sent successfully", {
                    hangoutId,
                    inviterId,
                    phoneNumber: formattedNumber,
                    twilioSid: twilioResponse.sid,
                });
                // Store invite record in Firestore
                logger.info("💾 SMS Invite Function - Storing success record in Firestore");
                await admin.firestore().collection("sms_invites").add({
                    hangoutId,
                    inviterId,
                    inviterName,
                    phoneNumber: formattedNumber,
                    sentAt: admin.firestore.FieldValue.serverTimestamp(),
                    status: "sent",
                    twilioSid: twilioResponse.sid,
                });
            }
            catch (error) {
                results.failedInvites++;
                const errorMessage = error instanceof Error ? error.message : "Unknown error";
                results.errors.push(`${phoneNumber}: ${errorMessage}`);
                logger.error("❌ Failed to send SMS invite", {
                    hangoutId,
                    inviterId,
                    phoneNumber,
                    error: errorMessage,
                    errorType: error instanceof Error ? error.constructor.name : typeof error,
                });
                // Store failed invite record
                logger.info("💾 SMS Invite Function - Storing failed record in Firestore");
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
        logger.info("⏳ SMS Invite Function - Waiting for all SMS sends to complete");
        await Promise.all(sendPromises);
        logger.info("✅ SMS Invite Function - All SMS sends completed");
        // Update results
        logger.info("📊 SMS Invite Function - Updating final results");
        if (results.failedInvites > 0 && results.successfulInvites === 0) {
            results.success = false;
            logger.warn("⚠️ SMS Invite Function - All invites failed, marking as unsuccessful");
        }
        logger.info("🎉 SMS invite batch completed", {
            hangoutId,
            inviterId,
            totalNumbers: phoneNumbers.length,
            successful: results.successfulInvites,
            failed: results.failedInvites,
            finalSuccess: results.success,
            errors: results.errors,
        });
        return results;
    }
    catch (error) {
        const errorMessage = error instanceof Error ? error.message : "Unknown error";
        logger.error("💥 SMS invite function error - Top level catch:", {
            error: errorMessage,
            errorType: error instanceof Error ? error.constructor.name : typeof error,
            stack: error instanceof Error ? error.stack : undefined,
        });
        return {
            success: false,
            successfulInvites: 0,
            failedInvites: 0,
            errors: [errorMessage],
        };
    }
});
//# sourceMappingURL=sms-invites.js.map