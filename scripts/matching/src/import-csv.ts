import { parse } from 'csv-parse/sync';
import { readFileSync } from 'fs';
import { v4 as uuidv4 } from 'uuid';
import { loadConfig } from './config.js';
import { initializeFirebase, getFirestore } from './firebase/client.js';
import { log } from './utils/logger.js';

interface CsvRow {
  'Timestamp': string;
  'what is your gender?': string;
  'when do you graduate?': string;
  'where do you live? ': string;
  'who are you looking to be friends with?': string;
  'what do you like to do for fun?': string;
  'what are some topics you could talk about forever?': string;
  'having deep/intellectual conversations ': string;
  'doing stuff outdoors (i.e. hiking, walking, camping)': string;
  'just chilling (i.e. indoor, games, phones, shooting the shit, no need to talk)': string;
  'competitive games (i.e. video games, board games, mini golf, pool)': string;
  'grabbing a meal': string;
  'nights out (i.e. party, club, bar)': string;
  'anything else you\'d like me to know?': string;
}

function parseRating(value: string): number {
  const num = parseInt(value, 10);
  if (isNaN(num) || num < 1) return 3;
  if (num > 5) return 5;
  return num;
}

function normalizeGender(value: string): string | null {
  const lower = value.toLowerCase().trim();
  if (lower.includes('female') && !lower.includes('male')) return 'female';
  if (lower.includes('male') && !lower.includes('female')) return 'male';
  if (lower.includes('non-binary') || lower.includes('nonbinary')) return 'non-binary';
  if (lower === 'female') return 'female';
  if (lower === 'male') return 'male';
  return value.trim() || null;
}

function normalizeGenderPreference(value: string): string {
  const lower = value.toLowerCase().trim();
  if (!lower) return 'any';

  const hasMale = lower.includes('male') && !lower.includes('female');
  const hasFemale = lower.includes('female');
  const hasNonBinary = lower.includes('non-binary') || lower.includes('nonbinary');

  // If all three or complex, just return 'any'
  if ((hasMale || lower.includes('male')) && hasFemale && hasNonBinary) return 'any';

  // Return the original trimmed value for specificity
  return value.trim();
}

async function importCsv(csvPath: string, dryRun: boolean = false) {
  const config = loadConfig();
  initializeFirebase(config);
  const db = getFirestore();

  log.info(`Reading CSV from: ${csvPath}`);

  const csvContent = readFileSync(csvPath, 'utf-8');
  const records: CsvRow[] = parse(csvContent, {
    columns: true,
    skip_empty_lines: true,
    relax_column_count: true,
  });

  log.info(`Found ${records.length} records`);

  const batch = db.batch();
  let count = 0;

  for (const row of records) {
    const userId = uuidv4();

    const gender = normalizeGender(row['what is your gender?']);
    const classYear = row['when do you graduate?']?.trim() || null;
    const location = row['where do you live? ']?.trim() || null;

    const userDoc = {
      id: userId,
      email: `imported-${userId.slice(0, 8)}@placeholder.local`,
      username: `user_${userId.slice(0, 8)}`,
      displayName: null,
      photoUrl: null,
      bio: row['anything else you\'d like me to know?']?.trim() || null,
      classYear,
      location,
      interests: [],
      gender,
      createdAt: Date.now(),
      lastSeen: null,
      isOnline: false,
      groupId: null,
      hasCreatedProfile: true,
      fcmToken: null,
      subscribedTopics: [],
      blockedUserIds: [],
      blockedByUserIds: [],
      authProvider: 'imported',
      isEmailVerified: false,
      verifiedEmail: null,
      appleUserId: null,
      hangoutChatNotifications: {},
      genderChangeCount: 0,
      genderChangedAt: null,
      matchingProfile: {
        isActive: true,
        genderPreference: normalizeGenderPreference(row['who are you looking to be friends with?']),
        funActivities: row['what do you like to do for fun?']?.trim() || null,
        talkAboutForever: row['what are some topics you could talk about forever?']?.trim() || null,
        activityRatings: {
          deepConversations: parseRating(row['having deep/intellectual conversations ']),
          outdoors: parseRating(row['doing stuff outdoors (i.e. hiking, walking, camping)']),
          chilling: parseRating(row['just chilling (i.e. indoor, games, phones, shooting the shit, no need to talk)']),
          competitiveGames: parseRating(row['competitive games (i.e. video games, board games, mini golf, pool)']),
          meals: parseRating(row['grabbing a meal']),
          nightsOut: parseRating(row['nights out (i.e. party, club, bar)']),
        },
        updatedAt: Date.now(),
      },
    };

    if (dryRun) {
      log.info(`[DRY RUN] Would create user:`);
      log.dim(`  ID: ${userId}`);
      log.dim(`  Gender: ${gender} | Year: ${classYear} | Location: ${location}`);
      log.dim(`  Looking for: ${userDoc.matchingProfile.genderPreference}`);
      log.dim(`  Fun: ${userDoc.matchingProfile.funActivities?.slice(0, 50)}...`);
      log.dim(`  Ratings: deep=${userDoc.matchingProfile.activityRatings.deepConversations} outdoors=${userDoc.matchingProfile.activityRatings.outdoors} chill=${userDoc.matchingProfile.activityRatings.chilling} games=${userDoc.matchingProfile.activityRatings.competitiveGames} meals=${userDoc.matchingProfile.activityRatings.meals} nights=${userDoc.matchingProfile.activityRatings.nightsOut}`);
      console.log('');
    } else {
      const ref = db.collection('users').doc(userId);
      batch.set(ref, userDoc);
    }

    count++;
  }

  if (!dryRun) {
    log.info(`Committing ${count} users to Firestore...`);
    await batch.commit();
    log.success(`Successfully imported ${count} users!`);
  } else {
    log.info(`[DRY RUN] Would import ${count} users`);
  }
}

// Parse args
const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const csvPath = args.find(a => !a.startsWith('--')) || './data/friend_matching_cleaned.csv';

importCsv(csvPath, dryRun).catch((err) => {
  log.error(err instanceof Error ? err.message : String(err));
  process.exit(1);
});
