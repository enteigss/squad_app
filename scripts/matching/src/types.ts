import { z } from 'zod';
import type { firestore } from 'firebase-admin';

// ============ Matching Profile (stored in user document) ============

export const MatchingProfileSchema = z.object({
  isActive: z.boolean().default(false),
  genderPreference: z.string().nullable().default(null),
  funActivities: z.string().nullable().default(null),
  talkAboutForever: z.string().nullable().default(null),
  freeTime: z.string().nullable().default(null),
  excludedActivities: z.array(z.string()).default([]),
  rankedActivities: z.array(z.string()).default([]),
  friendType: z.string().nullable().default(null),
  friendTypeMatchWell: z.string().nullable().default(null),
  friendTypeNoMatch: z.string().nullable().default(null),
  updatedAt: z.number().nullable().default(null),
});

export type MatchingProfile = z.infer<typeof MatchingProfileSchema>;

// ============ User Profile (mirrors UserModel from Dart) ============

export const UserProfileSchema = z.object({
  id: z.string(),
  email: z.string().default(''),
  username: z.string().default(''),
  displayName: z.string().nullable().default(null),
  bio: z.string().nullable().default(null),
  classYear: z.string().nullable().default(null),
  location: z.string().nullable().default(null),
  interests: z.array(z.string()).default([]),
  gender: z.string().nullable().default(null),
  hasCreatedProfile: z.boolean().default(false),
  blockedUserIds: z.array(z.string()).default([]),
  blockedByUserIds: z.array(z.string()).default([]),
  matchingProfile: MatchingProfileSchema.nullable().default(null),
});

export type UserProfile = z.infer<typeof UserProfileSchema>;

// ============ User For Matching (sent to Claude, no PII) ============

export interface UserForMatching {
  id: string;
  gender: string | null;
  graduationYear: string | null;
  location: string | null;
  genderPreference: string | null;
  funActivities: string | null;
  talkAboutForever: string | null;
  freeTime: string | null;
  excludedActivities: string[];
  rankedActivities: string[];
  friendType: string | null;
  friendTypeMatchWell: string | null;
  friendTypeNoMatch: string | null;
}

// ============ Match Result (from Claude API) ============

export const MatchResultSchema = z.object({
  memberIds: z.array(z.string()).min(2),
  reasoning: z.string().min(1),
  potentialDownside: z.string().min(1),
  sharedInterests: z.string().min(1),
});

export type MatchResult = z.infer<typeof MatchResultSchema>;

// Claude API response schema
export const ClaudeMatchResponseSchema = z.object({
  matches: z.array(MatchResultSchema),
  unmatchedUserIds: z.array(z.string()).optional(),
});

export type ClaudeMatchResponse = z.infer<typeof ClaudeMatchResponseSchema>;

// ============ Match Document (mirrors MatchModel from Dart) ============

export const MatchStatusEnum = z.enum([
  'pending',
  'active',
  'completed',
  'expired',
  'declined',
]);

export type MatchStatus = z.infer<typeof MatchStatusEnum>;

export interface MatchDocument {
  id: string;
  groupId: string;
  memberIds: string[];
  reasoning: string;
  potentialDownside: string;
  sharedInterests: string;
  createdAt: number; // milliseconds since epoch
  status: MatchStatus;
}

// ============ Matched Group Document (mirrors MatchedGroupModel from Dart) ============

export const MatchedGroupStatusEnum = z.enum([
  'active',
  'archived',
]);

export type MatchedGroupStatus = z.infer<typeof MatchedGroupStatusEnum>;

export interface MatchedGroupDocument {
  id: string;
  name: string;
  description: string | null;
  imageUrl: string | null;
  memberIds: string[];
  matchId: string | null;
  createdAt: firestore.Timestamp;
  status: MatchedGroupStatus;
  archivedAt: firestore.Timestamp | null;
  lastMessageId: string | null;
  lastMessageTime: firestore.Timestamp | null;
  lastMessagePreview: string | null;
  sharedInterests: string | null;
}

// ============ Output File Format ============

export interface MatchOutputFile {
  generatedAt: string; // ISO timestamp
  environment: string;
  totalUsers: number;
  totalMatches: number;
  promptFile: string;
  users: UserForMatching[]; // For review context
  matches: MatchResult[];
  unmatchedUserIds: string[];
}
