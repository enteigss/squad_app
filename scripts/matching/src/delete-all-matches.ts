/**
 * Script to delete all documents from matches and matched_groups collections
 *
 * Usage: npx tsx src/delete-all-matches.ts [--dry-run]
 */

import admin from 'firebase-admin';
import { readFileSync } from 'fs';
import path from 'path';

const isDryRun = process.argv.includes('--dry-run');

// Initialize Firebase
const serviceAccountPath = path.resolve('./service-account.json');
const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf-8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: process.env.FIREBASE_PROJECT || 'linkup-bu-test-environment',
});

const db = admin.firestore();

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

  // Delete in batches (Firestore batch limit is 500)
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

async function deleteAllMatches() {
  console.log(isDryRun ? '🔍 DRY RUN - No changes will be made\n' : '');
  console.log('🗑️  Deleting all matches and matched groups...\n');

  // Delete from matches collection
  console.log('📁 matches collection:');
  const matchesDeleted = await deleteCollection('matches');

  // Delete from matched_groups collection
  console.log('\n📁 matched_groups collection:');
  const groupsDeleted = await deleteCollection('matched_groups');

  console.log('');

  if (isDryRun) {
    console.log(`🔍 DRY RUN complete.`);
    console.log(`   Would delete ${matchesDeleted} matches and ${groupsDeleted} matched groups.`);
    console.log(`   Run without --dry-run to execute deletion.`);
  } else {
    console.log(`🎉 Done! Deleted ${matchesDeleted} matches and ${groupsDeleted} matched groups.`);
  }
}

deleteAllMatches()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Error:', err);
    process.exit(1);
  });
