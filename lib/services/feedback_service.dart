import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/meetup_feedback.dart';
import '../models/post_model.dart';

class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _feedbackCollection = 'meetup_feedback';
  final String _pendingPromptsCollection = 'pending_feedback_prompts';

  // Create pending feedback prompts for all participants when a hangout completes
  Future<void> createFeedbackPromptsForCompletedHangout(
    Post completedPost,
  ) async {
    debugPrint(
      'FeedbackService: createFeedbackPromptsForCompletedHangout called for ${completedPost.id}',
    );
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();

      // Create a pending prompt for each participant (except if they have < 2 participants)
      // TODO: Change back to < 2 for production
      if (completedPost.participantIds.length < 1) {
        debugPrint(
          'Skipping feedback collection for hangout with < 1 participants',
        );
        return;
      }

      for (final userId in completedPost.participantIds) {
        debugPrint('FeedbackService: Creating prompt for userId: $userId');
        final promptId = '${completedPost.id}_$userId';
        debugPrint('FeedbackService: Generated promptId: $promptId');
        final promptRef = _firestore
            .collection(_pendingPromptsCollection)
            .doc(promptId);

        final prompt = PendingFeedbackPrompt(
          id: promptId,
          hangoutId: completedPost.id,
          userId: userId,
          hangoutTitle: completedPost.title,
          hangoutCompletedAt: now,
          createdAt: now,
        );

        batch.set(promptRef, prompt.toMap());
      }

      final commitTime = DateTime.now();
      debugPrint('FeedbackService: Committing batch at: ${commitTime.toIso8601String()}');
      
      await batch.commit();
      
      final completedTime = DateTime.now();
      final commitDuration = completedTime.difference(commitTime).inMilliseconds;
      debugPrint('FeedbackService: Batch committed in ${commitDuration}ms');
      debugPrint(
        'Created ${completedPost.participantIds.length} feedback prompts for hangout: ${completedPost.title}',
      );
    } catch (e) {
      debugPrint('Failed to create feedback prompts: $e');
      rethrow;
    }
  }

  // Get pending feedback prompts for a specific user
  Stream<List<PendingFeedbackPrompt>> getPendingFeedbackPrompts(String userId) {
    debugPrint('FeedbackService: getPendingFeedbackPrompts for user $userId');
    debugPrint('FeedbackService: Query requires compound index on: userId + isShown + createdAt');
    
    final queryStartTime = DateTime.now();
    debugPrint('FeedbackService: Starting query at: ${queryStartTime.toIso8601String()}');
    
    return _firestore
        .collection(_pendingPromptsCollection)
        .where('userId', isEqualTo: userId)
        .where('isShown', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(5) // Only show up to 5 pending prompts at a time
        .snapshots()
        .map((snapshot) {
          final detectionTime = DateTime.now();
          debugPrint('FeedbackService: Query detected changes at: ${detectionTime.toIso8601String()}');
          debugPrint(
            'FeedbackService: Query returned ${snapshot.docs.length} documents',
          );
          
          // Log each document timestamp to measure freshness
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final createdAt = data['createdAt'];
            if (createdAt != null) {
              final docCreatedTime = (createdAt as Timestamp).toDate();
              final delay = detectionTime.difference(docCreatedTime).inMilliseconds;
              debugPrint('FeedbackService: Document ${doc.id} created at ${docCreatedTime.toIso8601String()}, detected after ${delay}ms');
            }
          }
          
          return snapshot.docs
              .map((doc) => PendingFeedbackPrompt.fromMap(doc.data()))
              .toList();
        });
  }

  // Mark a feedback prompt as shown
  Future<void> markPromptAsShown(String promptId) async {
    try {
      debugPrint(
        'FeedbackService: markPromptAsShown called for promptId: $promptId',
      );
      await _firestore
          .collection(_pendingPromptsCollection)
          .doc(promptId)
          .update({
            'isShown': true,
            'shownAt': Timestamp.fromDate(DateTime.now()),
          });
      debugPrint('FeedbackService: Successfully marked prompt as shown');
    } catch (e) {
      debugPrint('FeedbackService: Failed to mark prompt as shown: $e');
      rethrow;
    }
  }

  // Submit meetup feedback
  Future<void> submitFeedback({
    required String hangoutId,
    required String userId,
    required String hangoutTitle,
    required bool didMeetup,
    String? additionalFeedback,
  }) async {
    try {
      // Ensure user is authenticated before proceeding
      await FirebaseAuth.instance.currentUser?.getIdToken(true); // Force token refresh
      
      // Create the feedback document
      final feedbackRef = _firestore.collection(_feedbackCollection).doc();
      final feedback = MeetupFeedback(
        id: feedbackRef.id,
        hangoutId: hangoutId,
        userId: userId,
        hangoutTitle: hangoutTitle,
        didMeetup: didMeetup,
        additionalFeedback: additionalFeedback,
        submittedAt: DateTime.now(),
      );

      // Debug: Check feedback data
      debugPrint('FeedbackService: Submitting feedback for userId: $userId');
      debugPrint('FeedbackService: Feedback document userId: ${feedback.userId}');
      debugPrint('FeedbackService: Current Firebase user: ${FirebaseAuth.instance.currentUser?.uid}');
      debugPrint('FeedbackService: User authenticated: ${FirebaseAuth.instance.currentUser != null}');
      debugPrint('FeedbackService: Feedback data: ${feedback.toMap()}');

      // First, save the feedback separately
      debugPrint('FeedbackService: Saving feedback document...');
      await feedbackRef.set(feedback.toMap());
      debugPrint('FeedbackService: Feedback saved successfully!');

      // Then, try to remove the pending prompt
      final promptId = '${hangoutId}_$userId';
      debugPrint('FeedbackService: Deleting prompt with ID: $promptId');
      final promptRef = _firestore
          .collection(_pendingPromptsCollection)
          .doc(promptId);
      
      try {
        await promptRef.delete();
        debugPrint('FeedbackService: Prompt deleted successfully!');
      } catch (e) {
        debugPrint('FeedbackService: Failed to delete prompt (this is OK if it doesn\'t exist): $e');
        // Don't throw - feedback was saved successfully
      }

      debugPrint(
        'Submitted feedback for hangout $hangoutId: didMeetup=$didMeetup',
      );
    } catch (e) {
      debugPrint('Failed to submit feedback: $e');
      rethrow;
    }
  }

  // Get feedback statistics for analytics
  Future<Map<String, dynamic>> getFeedbackStats() async {
    try {
      final snapshot = await _firestore.collection(_feedbackCollection).get();

      if (snapshot.docs.isEmpty) {
        return {
          'totalFeedbacks': 0,
          'successfulMeetups': 0,
          'unsuccessfulMeetups': 0,
          'successRate': 0.0,
        };
      }

      int successfulMeetups = 0;
      int totalFeedbacks = snapshot.docs.length;

      for (final doc in snapshot.docs) {
        final feedback = MeetupFeedback.fromMap(doc.data());
        if (feedback.didMeetup) {
          successfulMeetups++;
        }
      }

      final unsuccessfulMeetups = totalFeedbacks - successfulMeetups;
      final successRate = successfulMeetups / totalFeedbacks;

      return {
        'totalFeedbacks': totalFeedbacks,
        'successfulMeetups': successfulMeetups,
        'unsuccessfulMeetups': unsuccessfulMeetups,
        'successRate': successRate,
      };
    } catch (e) {
      debugPrint('Failed to get feedback stats: $e');
      return {
        'totalFeedbacks': 0,
        'successfulMeetups': 0,
        'unsuccessfulMeetups': 0,
        'successRate': 0.0,
      };
    }
  }

  // Clean up old pending prompts (older than 7 days)
  Future<void> cleanupOldPendingPrompts() async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final snapshot = await _firestore
          .collection(_pendingPromptsCollection)
          .where('createdAt', isLessThan: Timestamp.fromDate(sevenDaysAgo))
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();

        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();
        debugPrint('Cleaned up ${snapshot.docs.length} old pending prompts');
      }
    } catch (e) {
      debugPrint('Failed to cleanup old pending prompts: $e');
    }
  }

  // Get all feedback for a specific hangout (for analytics)
  Future<List<MeetupFeedback>> getFeedbackForHangout(String hangoutId) async {
    try {
      final snapshot = await _firestore
          .collection(_feedbackCollection)
          .where('hangoutId', isEqualTo: hangoutId)
          .get();

      return snapshot.docs
          .map((doc) => MeetupFeedback.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Failed to get feedback for hangout: $e');
      return [];
    }
  }
}
