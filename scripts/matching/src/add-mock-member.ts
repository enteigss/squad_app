/**
 * Script to add a mock user to the matched group for testing
 *
 * Usage: npx tsx src/add-mock-member.ts
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

async function addMockMember() {
  const yourUserId = 'pXTaDt6bWaYy7A5XGEW4NEoyKDh1';
  const groupId = 'mock_match_1768973278558';

  // Create a mock user
  const mockUserId = `mock_user_${Date.now()}`;
  const mockUser = {
    id: mockUserId,
    email: 'alex.chen@bu.edu',
    username: 'alexchen',
    displayName: 'Alex Chen',
    photoUrl: null,
    bio: 'CS major who loves hiking, board games, and trying new restaurants. Always down for a spontaneous adventure!',
    classYear: '2026',
    location: 'West Campus',
    interests: ['hiking', 'board games', 'food', 'technology'],
    gender: 'male',
    createdAt: admin.firestore.Timestamp.now(),
    isOnline: false,
    hasCreatedProfile: true,
    authProvider: 'google',
    isEmailVerified: true,
  };

  console.log('📝 Creating mock user: Alex Chen...');
  await db.collection('users').doc(mockUserId).set(mockUser);
  console.log(`✅ Mock user created: ${mockUserId}`);

  // Update the matched group to include the new member
  console.log('📝 Adding mock user to matched group...');
  await db.collection('matched_groups').doc(groupId).update({
    memberIds: admin.firestore.FieldValue.arrayUnion(mockUserId),
    name: 'Alex & Jordan',
  });

  console.log(`✅ Mock user added to group!`);
  console.log(`   Group now has members: ${yourUserId}, ${mockUserId}`);
  console.log('\n🎉 Refresh the Connect tab to see the updated group with Alex!');
}

addMockMember()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Error:', err);
    process.exit(1);
  });
