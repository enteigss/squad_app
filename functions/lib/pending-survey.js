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
exports.syncPendingSurveyData = exports.importSurveyResponse = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = __importStar(require("firebase-admin"));
const firebase_functions_1 = require("firebase-functions");
// ============ Helpers ============
function parseRating(value) {
    const num = typeof value === "number" ? value : parseInt(String(value), 10);
    if (isNaN(num) || num < 1)
        return 3;
    if (num > 5)
        return 5;
    return num;
}
function normalizeGender(value) {
    if (!value || typeof value !== "string")
        return null;
    const lower = value.toLowerCase().trim();
    if (lower.includes("female") && !lower.includes("male"))
        return "female";
    if (lower.includes("male") && !lower.includes("female"))
        return "male";
    if (lower.includes("non-binary") || lower.includes("nonbinary")) {
        return "non-binary";
    }
    return value.trim() || null;
}
function normalizeGenderPreference(value) {
    if (!value || typeof value !== "string")
        return "any";
    const lower = value.toLowerCase().trim();
    if (!lower || lower === "anyone" || lower === "any")
        return "any";
    return value.trim();
}
// ============ HTTP Function: Import Survey Response ============
exports.importSurveyResponse = (0, https_1.onRequest)({ cors: true, invoker: "public" }, async (req, res) => {
    if (req.method !== "POST") {
        res.status(405).json({ success: false, error: "Method not allowed" });
        return;
    }
    try {
        const data = req.body;
        // Validate email
        const email = typeof data.email === "string" ?
            data.email.toLowerCase().trim() : null;
        if (!email) {
            res.status(400).json({ success: false, error: "Email is required" });
            return;
        }
        firebase_functions_1.logger.info("Importing survey response", { email });
        const now = Date.now();
        const pendingDoc = {
            email,
            matchingProfile: {
                isActive: true,
                genderPreference: normalizeGenderPreference(data.genderPreference),
                funActivities: typeof data.funActivities === "string" ?
                    data.funActivities.trim() || null : null,
                talkAboutForever: typeof data.talkAboutForever === "string" ?
                    data.talkAboutForever.trim() || null : null,
                freeTime: typeof data.freeTime === "string" ?
                    data.freeTime.trim() || null : null,
                activityRatings: {
                    deepConversations: parseRating(data.deepConversations),
                    outdoors: parseRating(data.outdoors),
                    chilling: parseRating(data.chilling),
                    competitiveGames: parseRating(data.competitiveGames),
                    meals: parseRating(data.meals),
                    nightsOut: parseRating(data.nightsOut),
                },
                updatedAt: now,
            },
            gender: normalizeGender(data.gender),
            classYear: typeof data.graduationYear === "string" ?
                data.graduationYear.trim() || null : null,
            location: typeof data.location === "string" ?
                data.location.trim() || null : null,
            phoneNumber: typeof data.phoneNumber === "string" ?
                data.phoneNumber.trim() || null : null,
            anythingElse: typeof data.anythingElse === "string" ?
                data.anythingElse.trim() || null : null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        await admin.firestore()
            .collection("pending_matching_profiles")
            .doc(email)
            .set(pendingDoc);
        firebase_functions_1.logger.info("Survey response saved", { email });
        res.status(200).json({ success: true });
    }
    catch (error) {
        firebase_functions_1.logger.error("Error importing survey response", error);
        const message = error instanceof Error ? error.message : String(error);
        res.status(500).json({ success: false, error: message });
    }
});
// ============ Firestore Trigger: Sync Pending Survey on User Creation ============
exports.syncPendingSurveyData = (0, firestore_1.onDocumentCreated)("users/{uid}", async (event) => {
    var _a;
    const userData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!userData)
        return;
    const uid = event.params.uid;
    const email = typeof userData.email === "string" ?
        userData.email.toLowerCase().trim() : null;
    if (!email) {
        firebase_functions_1.logger.info("No email on new user, skipping survey sync", { uid });
        return;
    }
    try {
        const pendingRef = admin.firestore()
            .collection("pending_matching_profiles")
            .doc(email);
        const pendingSnap = await pendingRef.get();
        if (!pendingSnap.exists)
            return;
        const pending = pendingSnap.data();
        firebase_functions_1.logger.info("Found pending survey data for new user", { uid, email });
        // Build update — always set matchingProfile, conditionally set
        // top-level fields only if the user doc doesn't already have them
        const update = {
            matchingProfile: pending.matchingProfile,
        };
        if (!userData.gender && pending.gender) {
            update.gender = pending.gender;
        }
        if (!userData.classYear && pending.classYear) {
            update.classYear = pending.classYear;
        }
        if (!userData.location && pending.location) {
            update.location = pending.location;
        }
        await admin.firestore()
            .collection("users")
            .doc(uid)
            .update(update);
        // Clean up pending doc
        await pendingRef.delete();
        firebase_functions_1.logger.info("Synced pending survey data to user", { uid, email });
    }
    catch (error) {
        firebase_functions_1.logger.error("Error syncing pending survey data", { uid, email, error });
    }
});
//# sourceMappingURL=pending-survey.js.map