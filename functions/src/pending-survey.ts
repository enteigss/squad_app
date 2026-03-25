import {onRequest} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions";

// ============ Helpers ============

function parseRating(value: unknown): number {
  const num = typeof value === "number" ? value : parseInt(String(value), 10);
  if (isNaN(num) || num < 1) return 3;
  if (num > 5) return 5;
  return num;
}

function normalizeGender(value: unknown): string | null {
  if (!value || typeof value !== "string") return null;
  const lower = value.toLowerCase().trim();
  if (lower.includes("female") && !lower.includes("male")) return "female";
  if (lower.includes("male") && !lower.includes("female")) return "male";
  if (lower.includes("non-binary") || lower.includes("nonbinary")) {
    return "non-binary";
  }
  return value.trim() || null;
}

function normalizeGenderPreference(value: unknown): string {
  if (!value || typeof value !== "string") return "any";
  const lower = value.toLowerCase().trim();
  if (!lower || lower === "anyone" || lower === "any") return "any";
  return value.trim();
}

// ============ HTTP Function: Import Survey Response ============

export const importSurveyResponse = onRequest(
  {cors: true, invoker: "public"},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({success: false, error: "Method not allowed"});
      return;
    }

    try {
      const data = req.body;

      // Validate email
      const email = typeof data.email === "string" ?
        data.email.toLowerCase().trim() : null;
      if (!email) {
        res.status(400).json({success: false, error: "Email is required"});
        return;
      }

      logger.info("Importing survey response", {email});

      const now = Date.now();

      const pendingDoc = {
        email,
        matchingProfile: {
          isActive: true,
          genderPreference: normalizeGenderPreference(data.genderPreference),
          funActivities:
            typeof data.funActivities === "string" ?
              data.funActivities.trim() || null : null,
          talkAboutForever:
            typeof data.talkAboutForever === "string" ?
              data.talkAboutForever.trim() || null : null,
          freeTime:
            typeof data.freeTime === "string" ?
              data.freeTime.trim() || null : null,
          excludedActivities:
            Array.isArray(data.excludedActivities) ?
              data.excludedActivities.filter(
                (v: unknown) => typeof v === "string"
              ) : [],
          rankedActivities:
            Array.isArray(data.rankedActivities) ?
              data.rankedActivities.filter(
                (v: unknown) => typeof v === "string"
              ) : [],
          friendType:
            typeof data.friendType === "string" ?
              data.friendType.trim() || null : null,
          friendTypeMatchWell:
            typeof data.friendTypeMatchWell === "string" ?
              data.friendTypeMatchWell.trim() || null : null,
          friendTypeNoMatch:
            typeof data.friendTypeNoMatch === "string" ?
              data.friendTypeNoMatch.trim() || null : null,
          updatedAt: now,
        },
        gender: normalizeGender(data.gender),
        classYear:
          typeof data.graduationYear === "string" ?
            data.graduationYear.trim() || null : null,
        location:
          typeof data.location === "string" ?
            data.location.trim() || null : null,
        phoneNumber:
          typeof data.phoneNumber === "string" ?
            data.phoneNumber.trim() || null : null,
        anythingElse:
          typeof data.anythingElse === "string" ?
            data.anythingElse.trim() || null : null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await admin.firestore()
        .collection("pending_matching_profiles")
        .doc(email)
        .set(pendingDoc);

      logger.info("Survey response saved", {email});

      // If a user with this email already exists, sync immediately
      const usersSnap = await admin.firestore()
        .collection("users")
        .where("email", "==", email)
        .limit(1)
        .get();

      if (!usersSnap.empty) {
        const userDoc = usersSnap.docs[0];
        const userData = userDoc.data();
        const update: Record<string, unknown> = {
          matchingProfile: pendingDoc.matchingProfile,
        };
        if (!userData.gender && pendingDoc.gender) {
          update.gender = pendingDoc.gender;
        }
        if (!userData.classYear && pendingDoc.classYear) {
          update.classYear = pendingDoc.classYear;
        }
        if (!userData.location && pendingDoc.location) {
          update.location = pendingDoc.location;
        }
        await userDoc.ref.update(update);
        await admin.firestore()
          .collection("pending_matching_profiles")
          .doc(email)
          .delete();
        logger.info("Synced survey directly to existing user", {
          uid: userDoc.id, email,
        });
      }

      res.status(200).json({success: true});
    } catch (error: unknown) {
      logger.error("Error importing survey response", error);
      const message = error instanceof Error ? error.message : String(error);
      res.status(500).json({success: false, error: message});
    }
  }
);

// ============ Firestore Trigger: Sync Pending Survey on User Creation ============

export const syncPendingSurveyData = onDocumentCreated(
  "users/{uid}",
  async (event) => {
    const userData = event.data?.data();
    if (!userData) return;

    const uid = event.params.uid;
    const email = typeof userData.email === "string" ?
      userData.email.toLowerCase().trim() : null;

    if (!email) {
      logger.info("No email on new user, skipping survey sync", {uid});
      return;
    }

    try {
      const pendingRef = admin.firestore()
        .collection("pending_matching_profiles")
        .doc(email);
      const pendingSnap = await pendingRef.get();

      if (!pendingSnap.exists) return;

      const pending = pendingSnap.data()!;
      logger.info("Found pending survey data for new user", {uid, email});

      // Build update — always set matchingProfile, conditionally set
      // top-level fields only if the user doc doesn't already have them
      const update: Record<string, unknown> = {
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

      logger.info("Synced pending survey data to user", {uid, email});
    } catch (error) {
      logger.error("Error syncing pending survey data", {uid, email, error});
    }
  }
);
