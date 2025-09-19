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
exports.deleteUserAccount = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const firebase_functions_1 = require("firebase-functions");
const db = admin.firestore();
const auth = admin.auth();
const storage = admin.storage();
exports.deleteUserAccount = (0, https_1.onCall)({ maxInstances: 1 }, // Limit concurrent executions
async (request) => {
    const { userId } = request.data;
    const { uid: callerUid } = request.auth || {};
    // Security check: user can only delete their own account
    if (!callerUid || callerUid !== userId) {
        firebase_functions_1.logger.error(`Unauthorized deletion attempt: caller ${callerUid} tried to delete ${userId}`);
        throw new Error("Unauthorized: You can only delete your own account");
    }
    firebase_functions_1.logger.info(`Starting account deletion for user: ${userId}`);
    const deletionStats = {
        posts: 0,
        messages: 0,
        groups: 0,
        reports: 0,
        invitations: 0,
        mediaFiles: 0,
    };
    try {
        // Step 1: Delete all posts created by the user
        firebase_functions_1.logger.info("Step 1: Deleting user posts...");
        const postsQuery = await db.collection("posts")
            .where("authorId", "==", userId)
            .get();
        const batch1 = db.batch();
        for (const postDoc of postsQuery.docs) {
            // Delete post chat messages
            const messagesQuery = await db.collection("posts")
                .doc(postDoc.id)
                .collection("messages")
                .get();
            for (const messageDoc of messagesQuery.docs) {
                batch1.delete(messageDoc.ref);
                deletionStats.messages++;
            }
            // Delete the post itself
            batch1.delete(postDoc.ref);
            deletionStats.posts++;
        }
        await batch1.commit();
        firebase_functions_1.logger.info(`Deleted ${deletionStats.posts} posts and their messages`);
        // Step 2: Remove user from groups and delete their messages
        firebase_functions_1.logger.info("Step 2: Removing user from groups...");
        const groupsQuery = await db.collection("groups")
            .where("memberIds", "array-contains", userId)
            .get();
        const batch2 = db.batch();
        for (const groupDoc of groupsQuery.docs) {
            const groupData = groupDoc.data();
            const memberIds = groupData.memberIds || [];
            const adminIds = groupData.adminIds || [];
            // Remove user from memberIds and adminIds
            const updatedMemberIds = memberIds.filter((id) => id !== userId);
            const updatedAdminIds = adminIds.filter((id) => id !== userId);
            if (updatedMemberIds.length === 0) {
                // If user was the only member, delete the entire group
                batch2.delete(groupDoc.ref);
                // Delete all messages in the group
                const groupMessagesQuery = await db.collection("groups")
                    .doc(groupDoc.id)
                    .collection("messages")
                    .get();
                for (const messageDoc of groupMessagesQuery.docs) {
                    batch2.delete(messageDoc.ref);
                    deletionStats.messages++;
                }
            }
            else {
                // Update group membership
                batch2.update(groupDoc.ref, {
                    memberIds: updatedMemberIds,
                    adminIds: updatedAdminIds,
                });
                // Delete user's messages in this group
                const userMessagesQuery = await db.collection("groups")
                    .doc(groupDoc.id)
                    .collection("messages")
                    .where("senderId", "==", userId)
                    .get();
                for (const messageDoc of userMessagesQuery.docs) {
                    batch2.delete(messageDoc.ref);
                    deletionStats.messages++;
                }
            }
            deletionStats.groups++;
        }
        await batch2.commit();
        firebase_functions_1.logger.info(`Processed ${deletionStats.groups} groups`);
        // Step 3: Delete reports (made by user and about user)
        firebase_functions_1.logger.info("Step 3: Deleting reports...");
        const batch3 = db.batch();
        const reportsByUserQuery = await db.collection("reports")
            .where("reportedBy", "==", userId)
            .get();
        const reportsAboutUserQuery = await db.collection("reports")
            .where("reportedUserId", "==", userId)
            .get();
        for (const reportDoc of reportsByUserQuery.docs) {
            batch3.delete(reportDoc.ref);
            deletionStats.reports++;
        }
        for (const reportDoc of reportsAboutUserQuery.docs) {
            batch3.delete(reportDoc.ref);
            deletionStats.reports++;
        }
        await batch3.commit();
        firebase_functions_1.logger.info(`Deleted ${deletionStats.reports} reports`);
        // Step 4: Delete party invitations
        firebase_functions_1.logger.info("Step 4: Deleting party invitations...");
        const userDoc = await db.collection("users").doc(userId).get();
        const userData = userDoc.data();
        const userEmail = userData === null || userData === void 0 ? void 0 : userData.email;
        if (userEmail) {
            const batch4 = db.batch();
            const sentInvitationsQuery = await db.collection("party_invitations")
                .where("inviterEmail", "==", userEmail)
                .get();
            const receivedInvitationsQuery = await db.collection("party_invitations")
                .where("inviteeEmail", "==", userEmail)
                .get();
            for (const inviteDoc of sentInvitationsQuery.docs) {
                batch4.delete(inviteDoc.ref);
                deletionStats.invitations++;
            }
            for (const inviteDoc of receivedInvitationsQuery.docs) {
                batch4.delete(inviteDoc.ref);
                deletionStats.invitations++;
            }
            await batch4.commit();
            firebase_functions_1.logger.info(`Deleted ${deletionStats.invitations} party invitations`);
        }
        // Step 5: Clean up block relationships
        firebase_functions_1.logger.info("Step 5: Cleaning up block relationships...");
        const allUsersQuery = await db.collection("users").get();
        const batch5 = db.batch();
        for (const userDocRef of allUsersQuery.docs) {
            const userData = userDocRef.data();
            const blockedUserIds = userData.blockedUserIds || [];
            const blockedByUserIds = userData.blockedByUserIds || [];
            let needsUpdate = false;
            const updatedData = {};
            if (blockedUserIds.includes(userId)) {
                updatedData.blockedUserIds = blockedUserIds.filter((id) => id !== userId);
                needsUpdate = true;
            }
            if (blockedByUserIds.includes(userId)) {
                updatedData.blockedByUserIds = blockedByUserIds.filter((id) => id !== userId);
                needsUpdate = true;
            }
            if (needsUpdate) {
                batch5.update(userDocRef.ref, updatedData);
            }
        }
        await batch5.commit();
        firebase_functions_1.logger.info("Cleaned up block relationships");
        // Step 6: Delete user feedback
        firebase_functions_1.logger.info("Step 6: Deleting user feedback...");
        const feedbackQuery = await db.collection("feedback")
            .where("userId", "==", userId)
            .get();
        const batch6 = db.batch();
        for (const feedbackDoc of feedbackQuery.docs) {
            batch6.delete(feedbackDoc.ref);
        }
        await batch6.commit();
        firebase_functions_1.logger.info(`Deleted ${feedbackQuery.docs.length} feedback entries`);
        // Step 7: Delete media files from Storage
        firebase_functions_1.logger.info("Step 7: Deleting media files...");
        try {
            const bucket = storage.bucket();
            // Delete profile photos
            try {
                await bucket.file(`profile_photos/${userId}`).delete();
                deletionStats.mediaFiles++;
            }
            catch (e) {
                firebase_functions_1.logger.info("Profile photo not found or already deleted");
            }
            // Delete post images (list files that contain the userId)
            const [postImages] = await bucket.getFiles({ prefix: "post_images/" });
            for (const file of postImages) {
                if (file.name.includes(userId)) {
                    await file.delete();
                    deletionStats.mediaFiles++;
                }
            }
            // Delete message attachments
            const [messageAttachments] = await bucket.getFiles({ prefix: "message_attachments/" });
            for (const file of messageAttachments) {
                if (file.name.includes(userId)) {
                    await file.delete();
                    deletionStats.mediaFiles++;
                }
            }
            firebase_functions_1.logger.info(`Deleted ${deletionStats.mediaFiles} media files`);
        }
        catch (e) {
            firebase_functions_1.logger.warn(`Error deleting media files: ${e}`);
        }
        // Step 8: Delete Firestore user document
        firebase_functions_1.logger.info("Step 8: Deleting user document...");
        await db.collection("users").doc(userId).delete();
        // Step 9: Delete Firebase Auth account (FINAL STEP)
        firebase_functions_1.logger.info("Step 9: Deleting Firebase Auth account...");
        await auth.deleteUser(userId);
        firebase_functions_1.logger.info(`Account deletion completed successfully for user: ${userId}`);
        return {
            success: true,
            message: "Account deleted successfully",
            deletedData: deletionStats,
        };
    }
    catch (error) {
        firebase_functions_1.logger.error(`Account deletion failed for user ${userId}:`, error);
        throw new Error(`Account deletion failed: ${error instanceof Error ? error.message : "Unknown error"}`);
    }
});
//# sourceMappingURL=account-deletion.js.map