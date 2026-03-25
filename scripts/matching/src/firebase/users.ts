import { getFirestore } from './client.js';
import { UserProfileSchema, type UserProfile, type UserForMatching, type ActivityRatings } from '../types.js';
import { log } from '../utils/logger.js';

export async function fetchEligibleUsers(collection: string = 'users'): Promise<UserProfile[]> {
  const db = getFirestore();

  log.info(`Fetching users from Firestore collection: ${collection}...`);

  // Fetch users who have opted into the matching pool
  const snapshot = await db
    .collection(collection)
    .where('matchingProfile.isActive', '==', true)
    .get();

  const users: UserProfile[] = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const parsed = UserProfileSchema.safeParse({ ...data, id: doc.id });

    if (parsed.success) {
      users.push(parsed.data);
    } else {
      const errors = parsed.error.issues.map(i => `${i.path.join('.')}: ${i.message}`).join(', ');
      log.warn(`Skipping user ${doc.id}: ${errors}`);
    }
  }

  log.success(`Fetched ${users.length} eligible users`);
  return users;
}

// Filter out blocked user pairs
export function filterBlockedUsers(users: UserProfile[]): UserProfile[] {
  // Create a set of all blocked relationships
  const blockedPairs = new Set<string>();

  for (const user of users) {
    for (const blockedId of user.blockedUserIds) {
      blockedPairs.add(`${user.id}:${blockedId}`);
      blockedPairs.add(`${blockedId}:${user.id}`);
    }
    for (const blockedById of user.blockedByUserIds) {
      blockedPairs.add(`${user.id}:${blockedById}`);
      blockedPairs.add(`${blockedById}:${user.id}`);
    }
  }

  log.info(`Found ${blockedPairs.size / 2} blocked relationships`);
  return users; // Return all users, blocked pairs handled during matching
}

// Default activity ratings
const defaultRatings: ActivityRatings = {
  deepConversations: 3,
  outdoors: 3,
  chilling: 3,
  competitiveGames: 3,
  meals: 3,
  nightsOut: 3,
};

// Convert to format safe for Claude (only matching-relevant data, no PII)
export function usersForMatching(users: UserProfile[]): UserForMatching[] {
  return users.map((u) => ({
    id: u.id,
    gender: u.gender,
    graduationYear: u.classYear,
    location: u.location,
    genderPreference: u.matchingProfile?.genderPreference ?? null,
    funActivities: u.matchingProfile?.funActivities ?? null,
    talkAboutForever: u.matchingProfile?.talkAboutForever ?? null,
    freeTime: u.matchingProfile?.freeTime ?? null,
    activityRatings: {
      deepConversations: u.matchingProfile?.activityRatings?.deepConversations ?? defaultRatings.deepConversations,
      outdoors: u.matchingProfile?.activityRatings?.outdoors ?? defaultRatings.outdoors,
      chilling: u.matchingProfile?.activityRatings?.chilling ?? defaultRatings.chilling,
      competitiveGames: u.matchingProfile?.activityRatings?.competitiveGames ?? defaultRatings.competitiveGames,
      meals: u.matchingProfile?.activityRatings?.meals ?? defaultRatings.meals,
      nightsOut: u.matchingProfile?.activityRatings?.nightsOut ?? defaultRatings.nightsOut,
    },
    activityPreferencesElaboration: u.matchingProfile?.activityPreferencesElaboration ?? null,
    friendType: u.matchingProfile?.friendType ?? null,
    friendTypeMatchWell: u.matchingProfile?.friendTypeMatchWell ?? null,
    friendTypeNoMatch: u.matchingProfile?.friendTypeNoMatch ?? null,
  }));
}

// Get blocked pairs as a set for prompt context
export function getBlockedPairs(users: UserProfile[]): string[][] {
  const pairs: string[][] = [];
  const seen = new Set<string>();

  for (const user of users) {
    for (const blockedId of [...user.blockedUserIds, ...user.blockedByUserIds]) {
      const key = [user.id, blockedId].sort().join(':');
      if (!seen.has(key)) {
        seen.add(key);
        pairs.push([user.id, blockedId]);
      }
    }
  }

  return pairs;
}
