import admin from 'firebase-admin';
import { getFirestore } from './client.js';
import { v4 as uuidv4 } from 'uuid';
import type { MatchDocument, MatchedGroupDocument, MatchOutputFile } from '../types.js';
import { log } from '../utils/logger.js';

export async function pushMatchesToFirestore(
  outputFile: MatchOutputFile
): Promise<void> {
  const db = getFirestore();
  const batch = db.batch();
  const now = admin.firestore.Timestamp.now();

  log.info(`Pushing ${outputFile.matches.length} matches to Firestore...`);

  for (const match of outputFile.matches) {
    const matchId = uuidv4();
    const groupId = uuidv4();

    // Create the match document
    const matchDoc: MatchDocument = {
      id: matchId,
      groupId: groupId,
      memberIds: match.memberIds,
      reasoning: match.reasoning,
      potentialDownside: match.potentialDownside,
      activitySuggestion: match.activitySuggestion,
      sharedInterests: match.sharedInterests,
      createdAt: Date.now(),
      status: 'pending',
    };

    const matchRef = db.collection('matches').doc(matchId);
    batch.set(matchRef, matchDoc);

    // Create corresponding matched group for the matched users
    const matchedGroupDoc: MatchedGroupDocument = {
      id: groupId,
      name: 'New Match',
      description: match.reasoning,
      imageUrl: null,
      memberIds: match.memberIds,
      matchId: matchId,
      createdAt: now,
      status: 'active',
      archivedAt: null,
      lastMessageId: null,
      lastMessageTime: null,
      lastMessagePreview: null,
      activitySuggestion: match.activitySuggestion,
      sharedInterests: match.sharedInterests,
    };

    const groupRef = db.collection('matched_groups').doc(groupId);
    batch.set(groupRef, matchedGroupDoc);

    log.info(`  -> Match: ${match.memberIds.join(' + ')}`);
  }

  await batch.commit();
  log.success(`Successfully pushed ${outputFile.matches.length} matches`);
}
