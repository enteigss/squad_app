/**
 * Script to delete all users from the users collection and Firebase Auth
 *
 * Usage: npx tsx src/delete-all-users.ts [--dry-run]
 */

import admin from 'firebase-admin';
import { readFileSync } from 'fs';
import path from 'path';

const isDryRun = process.argv.includes('--dry-run');

// Initialize Firebase
const serviceAccountPath = path.resolve('./service-account.json');
const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf-8'));

const PROJECT_ID = 'linkup-bu-test-environment';

if (serviceAccount.project_id !== PROJECT_ID) {
  console.error(`❌ SAFETY CHECK FAILED: service account is for "${serviceAccount.project_id}", not "${PROJECT_ID}".`);
  console.error(`   This script is locked to the test environment only.`);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: PROJECT_ID,
});

const db = admin.firestore();
const auth = admin.auth();

async function deleteAllAuthUsers(): Promise<number> {
  let deleted = 0;
  let nextPageToken: string | undefined;

  do {
    const listResult = await auth.listUsers(1000, nextPageToken);

    if (listResult.users.length === 0) break;

    console.log(`  Found ${listResult.users.length} auth users in this batch`);

    if (!isDryRun) {
      const uids = listResult.users.map((u) => u.uid);
      await auth.deleteUsers(uids);
      console.log(`  Deleted ${uids.length} auth users`);
    }

    deleted += listResult.users.length;
    nextPageToken = listResult.pageToken;
  } while (nextPageToken);

  return deleted;
}

async function deleteCollection(collectionName: string): Promise<number> {
  const snapshot = await db.collection(collectionName).get();

  if (snapshot.empty) {
    console.log(`  No documents found in ${collectionName}`);
    return 0;
  }

  console.log(`  Found ${snapshot.size} documents in ${collectionName}`);

  if (isDryRun) {
    return snapshot.size;
  }

  const batchSize = 400;
  let deleted = 0;

  for (let i = 0; i < snapshot.docs.length; i += batchSize) {
    const batch = db.batch();
    const chunk = snapshot.docs.slice(i, i + batchSize);

    for (const doc of chunk) {
      batch.delete(doc.ref);
    }

    await batch.commit();
    deleted += chunk.length;
    console.log(`  Deleted ${deleted}/${snapshot.size}...`);
  }

  return deleted;
}

async function deleteAllUsers() {
  console.log(isDryRun ? '🔍 DRY RUN - No changes will be made\n' : '');
  console.log('🗑️  Deleting all users...\n');

  console.log('📁 users collection:');
  const usersDeleted = await deleteCollection('users');

  console.log('\n🔐 Firebase Auth:');
  const authDeleted = await deleteAllAuthUsers();

  console.log('');

  if (isDryRun) {
    console.log(`🔍 DRY RUN complete.`);
    console.log(`   Would delete ${usersDeleted} Firestore users and ${authDeleted} Auth users.`);
    console.log(`   Run without --dry-run to execute deletion.`);
  } else {
    console.log(`🎉 Done! Deleted ${usersDeleted} Firestore users and ${authDeleted} Auth users.`);
  }
}

deleteAllUsers()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Error:', err);
    process.exit(1);
  });
