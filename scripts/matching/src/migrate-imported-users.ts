/**
 * Script to migrate users with emails starting with "imported"
 * from `users` collection to `find_a_friend_users` collection
 *
 * Usage: npx tsx src/migrate-imported-users.ts [--dry-run]
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

async function migrateImportedUsers() {
  console.log(isDryRun ? '🔍 DRY RUN - No changes will be made\n' : '');

  // Fetch all users from the users collection
  console.log('📥 Fetching users from users collection...');
  const snapshot = await db.collection('users').get();

  // Filter users with emails starting with "imported"
  const usersToMigrate = snapshot.docs.filter(doc => {
    const email = doc.data().email || '';
    return email.toLowerCase().startsWith('imported');
  });

  console.log(`Found ${usersToMigrate.length} users with emails starting with "imported"\n`);

  if (usersToMigrate.length === 0) {
    console.log('No users to migrate.');
    return;
  }

  // Show users that will be migrated
  for (const doc of usersToMigrate) {
    const data = doc.data();
    console.log(`  - ${doc.id}: ${data.email} (${data.displayName || 'no name'})`);
  }
  console.log('');

  if (isDryRun) {
    console.log('🔍 DRY RUN complete. Run without --dry-run to execute migration.');
    return;
  }

  // Migrate users in batches (Firestore batch limit is 500)
  const batchSize = 400; // Leave room for deletes
  let migrated = 0;

  for (let i = 0; i < usersToMigrate.length; i += batchSize) {
    const batch = db.batch();
    const chunk = usersToMigrate.slice(i, i + batchSize);

    for (const doc of chunk) {
      const data = doc.data();

      // Add to find_a_friend_users collection (same document ID)
      const newRef = db.collection('find_a_friend_users').doc(doc.id);
      batch.set(newRef, data);

      // Delete from users collection
      const oldRef = db.collection('users').doc(doc.id);
      batch.delete(oldRef);
    }

    await batch.commit();
    migrated += chunk.length;
    console.log(`✅ Migrated ${migrated}/${usersToMigrate.length} users...`);
  }

  console.log(`\n🎉 Migration complete! Moved ${migrated} users to find_a_friend_users collection.`);
}

migrateImportedUsers()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Error:', err);
    process.exit(1);
  });
