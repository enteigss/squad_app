import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_app/models/meetup_feedback.dart';
import 'package:squad_app/services/feedback_service.dart';

import '../../fixtures/post_fixtures.dart';

void main() {
  group('FeedbackService', () {
    late FeedbackService feedbackService;
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;

    const testUserId = 'user-123';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: testUserId, isAnonymous: false),
      );
      feedbackService = FeedbackService(
        firestore: fakeFirestore,
        auth: mockAuth,
      );
    });

    /// Helper to seed a pending feedback prompt directly into Firestore
    Future<void> seedPrompt({
      required String id,
      required String hangoutId,
      required String userId,
      bool isShown = false,
      DateTime? createdAt,
    }) async {
      final now = createdAt ?? DateTime.now();
      final prompt = PendingFeedbackPrompt(
        id: id,
        hangoutId: hangoutId,
        userId: userId,
        hangoutCompletedAt: now,
        createdAt: now,
        isShown: isShown,
        shownAt: isShown ? now : null,
      );
      await fakeFirestore
          .collection('pending_feedback_prompts')
          .doc(id)
          .set(prompt.toMap());
    }

    /// Helper to seed a feedback document directly into Firestore
    Future<void> seedFeedback({
      required String id,
      required String hangoutId,
      required String userId,
      bool didMeetup = true,
      String? additionalFeedback,
    }) async {
      final feedback = MeetupFeedback(
        id: id,
        hangoutId: hangoutId,
        userId: userId,
        didMeetup: didMeetup,
        additionalFeedback: additionalFeedback,
        submittedAt: DateTime.now(),
      );
      await fakeFirestore
          .collection('meetup_feedback')
          .doc(id)
          .set(feedback.toMap());
    }

    group('createFeedbackPromptForAuthor', () {
      test('creates prompt document with correct fields', () async {
        // Arrange
        final post = PostFixtures.completedPost;

        // Act
        await feedbackService.createFeedbackPromptForAuthor(post);

        // Assert
        final promptId = '${post.id}_${post.authorId}';
        final doc = await fakeFirestore
            .collection('pending_feedback_prompts')
            .doc(promptId)
            .get();

        expect(doc.exists, true);
        expect(doc.data()?['hangoutId'], post.id);
        expect(doc.data()?['userId'], post.authorId);
        expect(doc.data()?['isShown'], false);
        expect(doc.data()?['shownAt'], isNull);
        expect(doc.data()?['createdAt'], isA<Timestamp>());
        expect(doc.data()?['hangoutCompletedAt'], isA<Timestamp>());
      });

      test('uses postId_authorId as document ID', () async {
        // Arrange
        final post = PostFixtures.completedPost;

        // Act
        await feedbackService.createFeedbackPromptForAuthor(post);

        // Assert
        final expectedId = '${post.id}_${post.authorId}';
        final doc = await fakeFirestore
            .collection('pending_feedback_prompts')
            .doc(expectedId)
            .get();
        expect(doc.exists, true);
        expect(doc.data()?['id'], expectedId);
      });
    });

    group('getPendingFeedbackPrompts', () {
      test('returns unshown prompts for the specified user', () async {
        // Arrange
        await seedPrompt(
          id: 'hangout1_$testUserId',
          hangoutId: 'hangout1',
          userId: testUserId,
        );
        await seedPrompt(
          id: 'hangout2_$testUserId',
          hangoutId: 'hangout2',
          userId: testUserId,
        );

        // Act
        final stream = feedbackService.getPendingFeedbackPrompts(testUserId);
        final prompts = await stream.first;

        // Assert
        expect(prompts.length, 2);
        expect(prompts.every((p) => p.userId == testUserId), true);
        expect(prompts.every((p) => p.isShown == false), true);
      });

      test('excludes shown prompts', () async {
        // Arrange
        await seedPrompt(
          id: 'shown_$testUserId',
          hangoutId: 'hangout-shown',
          userId: testUserId,
          isShown: true,
        );
        await seedPrompt(
          id: 'unshown_$testUserId',
          hangoutId: 'hangout-unshown',
          userId: testUserId,
          isShown: false,
        );

        // Act
        final stream = feedbackService.getPendingFeedbackPrompts(testUserId);
        final prompts = await stream.first;

        // Assert
        expect(prompts.length, 1);
        expect(prompts.first.hangoutId, 'hangout-unshown');
      });
    });

    group('markPromptAsShown', () {
      test('updates isShown to true and sets shownAt', () async {
        // Arrange
        const promptId = 'hangout1_$testUserId';
        await seedPrompt(
          id: promptId,
          hangoutId: 'hangout1',
          userId: testUserId,
        );

        // Act
        await feedbackService.markPromptAsShown(promptId);

        // Assert
        final doc = await fakeFirestore
            .collection('pending_feedback_prompts')
            .doc(promptId)
            .get();
        expect(doc.data()?['isShown'], true);
        expect(doc.data()?['shownAt'], isA<Timestamp>());
      });
    });

    group('submitFeedback', () {
      test('creates feedback document with correct fields', () async {
        // Act
        await feedbackService.submitFeedback(
          hangoutId: 'hangout-1',
          userId: testUserId,
          didMeetup: true,
          additionalFeedback: 'Great time!',
        );

        // Assert
        final snapshot =
            await fakeFirestore.collection('meetup_feedback').get();
        expect(snapshot.docs.length, 1);

        final data = snapshot.docs.first.data();
        expect(data['hangoutId'], 'hangout-1');
        expect(data['userId'], testUserId);
        expect(data['didMeetup'], true);
        expect(data['additionalFeedback'], 'Great time!');
        expect(data['submittedAt'], isA<Timestamp>());
      });

      test('deletes the associated pending prompt', () async {
        // Arrange
        const promptId = 'hangout-1_$testUserId';
        await seedPrompt(
          id: promptId,
          hangoutId: 'hangout-1',
          userId: testUserId,
        );

        // Act
        await feedbackService.submitFeedback(
          hangoutId: 'hangout-1',
          userId: testUserId,
          didMeetup: true,
        );

        // Assert
        final promptDoc = await fakeFirestore
            .collection('pending_feedback_prompts')
            .doc(promptId)
            .get();
        expect(promptDoc.exists, false);
      });

      test('succeeds even when no pending prompt exists', () async {
        // Act — no prompt seeded, should not throw
        await feedbackService.submitFeedback(
          hangoutId: 'hangout-no-prompt',
          userId: testUserId,
          didMeetup: false,
        );

        // Assert — feedback doc was still created
        final snapshot =
            await fakeFirestore.collection('meetup_feedback').get();
        expect(snapshot.docs.length, 1);
        expect(snapshot.docs.first.data()['hangoutId'], 'hangout-no-prompt');
      });
    });

    group('hasAuthorProvidedFeedback', () {
      test('returns true when feedback exists', () async {
        // Arrange
        await seedFeedback(
          id: 'fb-1',
          hangoutId: 'hangout-1',
          userId: testUserId,
        );

        // Act
        final result = await feedbackService.hasAuthorProvidedFeedback(
          'hangout-1',
          testUserId,
        );

        // Assert
        expect(result, true);
      });

      test('returns false when no feedback exists', () async {
        // Act
        final result = await feedbackService.hasAuthorProvidedFeedback(
          'hangout-nonexistent',
          testUserId,
        );

        // Assert
        expect(result, false);
      });
    });

    group('getFeedbackStats', () {
      test('returns zeros when no feedback exists', () async {
        // Act
        final stats = await feedbackService.getFeedbackStats();

        // Assert
        expect(stats['totalFeedbacks'], 0);
        expect(stats['successfulMeetups'], 0);
        expect(stats['unsuccessfulMeetups'], 0);
        expect(stats['successRate'], 0.0);
      });

      test('calculates correct success rate', () async {
        // Arrange — 2 successful, 1 unsuccessful
        await seedFeedback(
          id: 'fb-1',
          hangoutId: 'h1',
          userId: 'u1',
          didMeetup: true,
        );
        await seedFeedback(
          id: 'fb-2',
          hangoutId: 'h2',
          userId: 'u2',
          didMeetup: true,
        );
        await seedFeedback(
          id: 'fb-3',
          hangoutId: 'h3',
          userId: 'u3',
          didMeetup: false,
        );

        // Act
        final stats = await feedbackService.getFeedbackStats();

        // Assert
        expect(stats['totalFeedbacks'], 3);
        expect(stats['successfulMeetups'], 2);
        expect(stats['unsuccessfulMeetups'], 1);
        expect(stats['successRate'], closeTo(2 / 3, 0.001));
      });
    });

    group('getFeedbackForHangout', () {
      test('returns all feedback for a specific hangout', () async {
        // Arrange
        await seedFeedback(
          id: 'fb-1',
          hangoutId: 'hangout-target',
          userId: 'u1',
        );
        await seedFeedback(
          id: 'fb-2',
          hangoutId: 'hangout-target',
          userId: 'u2',
        );
        await seedFeedback(
          id: 'fb-other',
          hangoutId: 'hangout-other',
          userId: 'u3',
        );

        // Act
        final results =
            await feedbackService.getFeedbackForHangout('hangout-target');

        // Assert
        expect(results.length, 2);
        expect(results.every((f) => f.hangoutId == 'hangout-target'), true);
      });

      test('returns empty list for unknown hangoutId', () async {
        // Act
        final results =
            await feedbackService.getFeedbackForHangout('nonexistent');

        // Assert
        expect(results, isEmpty);
      });
    });

    group('cleanupOldPendingPrompts', () {
      test('deletes prompts older than 7 days', () async {
        // Arrange
        final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));
        await seedPrompt(
          id: 'old-prompt',
          hangoutId: 'old-hangout',
          userId: testUserId,
          createdAt: eightDaysAgo,
        );

        // Act
        await feedbackService.cleanupOldPendingPrompts();

        // Assert
        final doc = await fakeFirestore
            .collection('pending_feedback_prompts')
            .doc('old-prompt')
            .get();
        expect(doc.exists, false);
      });

      test('preserves recent prompts', () async {
        // Arrange
        final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
        await seedPrompt(
          id: 'recent-prompt',
          hangoutId: 'recent-hangout',
          userId: testUserId,
          createdAt: twoDaysAgo,
        );

        // Act
        await feedbackService.cleanupOldPendingPrompts();

        // Assert
        final doc = await fakeFirestore
            .collection('pending_feedback_prompts')
            .doc('recent-prompt')
            .get();
        expect(doc.exists, true);
      });
    });
  });
}
