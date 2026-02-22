import admin from 'firebase-admin';
import { readFileSync } from 'fs';
import type { AppConfig } from '../config.js';

let db: admin.firestore.Firestore | null = null;

export function initializeFirebase(config: AppConfig): admin.firestore.Firestore {
  if (db) return db;

  const serviceAccount = JSON.parse(
    readFileSync(config.firebaseServiceAccountPath, 'utf-8')
  );

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: config.firebaseProject,
  });

  db = admin.firestore();
  return db;
}

export function getFirestore(): admin.firestore.Firestore {
  if (!db) {
    throw new Error('Firebase not initialized. Call initializeFirebase first.');
  }
  return db;
}
