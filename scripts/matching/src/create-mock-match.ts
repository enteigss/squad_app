/**
 * Script to create a mock matched group for testing
 *
 * Usage: npx tsx src/create-mock-match.ts
 */

import admin from 'firebase-admin';
import { readFileSync } from 'fs';
import path from 'path';

// Initialize Firebase
const serviceAccountPath = path.resolve('./service-account.json');
const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf-8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: process.env.FIREBASE_PROJECT || 'linkup-bu-test-environment',
});

const db = admin.firestore();

async function createMockMatch() {
  console.log('🔍 Looking for user with email: enteigss@gmail.com');

  // Find the user by email
  const usersSnapshot = await db
    .collection('users')
    .where('email', '==', 'enteigss@gmail.com')
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    console.error('❌ User not found with email: enteigss@gmail.com');
    process.exit(1);
  }

  const userDoc = usersSnapshot.docs[0];
  const userId = userDoc.id;
  const userData = userDoc.data();
  console.log(`✅ Found user: ${userData.displayName || userData.email} (${userId})`);

  // Create a mock matched group
  const mockGroupId = `mock_match_${Date.now()}`;
  const mockGroup = {
    id: mockGroupId,
    name: 'Your Test Match',
    description: 'A mock matched group for testing the Connect tab',
    memberIds: [userId], // Just the user for now - single member group
    matchId: null,
    createdAt: admin.firestore.Timestamp.now(),
    status: 'active',
    archivedAt: null,
    lastMessageId: null,
    lastMessageTime: null,
    lastMessagePreview: null,
    activitySuggestion: 'Try grabbing coffee at the campus cafe and discussing your shared interest in technology!',
    sharedInterests: 'technology, video games, trying new restaurants',
  };

  console.log('📝 Creating mock matched group...');
  await db.collection('matched_groups').doc(mockGroupId).set(mockGroup);

  console.log(`✅ Mock matched group created!`);
  console.log(`   Group ID: ${mockGroupId}`);
  console.log(`   Members: ${mockGroup.memberIds.join(', ')}`);
  console.log('\n🎉 You should now see the matched groups list in the Connect tab!');
}

createMockMatch()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Error:', err);
    process.exit(1);
  });
