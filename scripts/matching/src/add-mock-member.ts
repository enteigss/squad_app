/**
 * Script to add 3 mock users to the matching pool for testing.
 * Creates user documents with matching profiles flagged as active.
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

const mockUsers = [
  {
    email: 'alex.chen@bu.edu',
    username: 'alexchen',
    displayName: 'Alex Chen',
    bio: 'CS major who loves hiking, board games, and trying new restaurants. Always down for a spontaneous adventure!',
    classYear: '2026',
    location: 'West Campus',
    interests: ['hiking', 'board games', 'food', 'technology'],
    gender: 'male',
    matchingProfile: {
      isActive: true,
      genderPreference: null,
      funActivities: 'Exploring new hiking trails, hosting board game nights, and finding the best hole-in-the-wall restaurants.',
      talkAboutForever: 'The future of AI, best travel destinations, and whether pineapple belongs on pizza.',
      freeTime: 'Usually coding side projects, playing basketball, or binging a good sci-fi show.',
      activityRatings: {
        deepConversations: 4,
        outdoors: 5,
        chilling: 3,
        competitiveGames: 5,
        meals: 4,
        nightsOut: 2,
      },
      updatedAt: Date.now(),
    },
  },
  {
    email: 'maya.patel@bu.edu',
    username: 'mayapatel',
    displayName: 'Maya Patel',
    bio: 'Pre-med student, yoga enthusiast, and amateur photographer. Love meeting new people over coffee.',
    classYear: '2027',
    location: 'South Campus',
    interests: ['yoga', 'photography', 'coffee', 'volunteering'],
    gender: 'female',
    matchingProfile: {
      isActive: true,
      genderPreference: null,
      funActivities: 'Morning yoga, weekend photography walks, and volunteering at the animal shelter.',
      talkAboutForever: 'Mental health awareness, documentary recommendations, and dream travel itineraries.',
      freeTime: 'Studying at my favorite café, journaling, or exploring the city with my camera.',
      activityRatings: {
        deepConversations: 5,
        outdoors: 4,
        chilling: 4,
        competitiveGames: 2,
        meals: 5,
        nightsOut: 3,
      },
      updatedAt: Date.now(),
    },
  },
  {
    email: 'jordan.kim@bu.edu',
    username: 'jordankim',
    displayName: 'Jordan Kim',
    bio: 'Business major, pickup basketball regular, and music nerd. Looking for people to grab late-night food with.',
    classYear: '2026',
    location: 'East Campus',
    interests: ['basketball', 'music', 'entrepreneurship', 'cooking'],
    gender: 'male',
    matchingProfile: {
      isActive: true,
      genderPreference: null,
      funActivities: 'Pickup basketball, going to concerts, and cooking elaborate meals for friends.',
      talkAboutForever: 'Startup ideas, music production, and hot takes about the NBA.',
      freeTime: 'At the gym, listening to new albums, or working on my side hustle.',
      activityRatings: {
        deepConversations: 3,
        outdoors: 3,
        chilling: 5,
        competitiveGames: 4,
        meals: 5,
        nightsOut: 5,
      },
      updatedAt: Date.now(),
    },
  },
];

async function addMockMembers() {
  console.log('Adding 3 mock users to the matching pool...\n');

  for (const mock of mockUsers) {
    const mockUserId = `mock_user_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;

    const userDoc = {
      id: mockUserId,
      email: mock.email,
      username: mock.username,
      displayName: mock.displayName,
      photoUrl: null,
      bio: mock.bio,
      classYear: mock.classYear,
      location: mock.location,
      interests: mock.interests,
      gender: mock.gender,
      createdAt: admin.firestore.Timestamp.now(),
      isOnline: false,
      hasCreatedProfile: true,
      authProvider: 'google',
      isEmailVerified: true,
      blockedUserIds: [],
      blockedByUserIds: [],
      matchingProfile: mock.matchingProfile,
    };

    await db.collection('users').doc(mockUserId).set(userDoc);
    console.log(`  Created ${mock.displayName} (${mockUserId})`);
  }

  console.log('\nAll 3 mock users added to the matching pool and ready to be matched.');
}

addMockMembers()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
