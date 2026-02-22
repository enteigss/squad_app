import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:squad_app/models/meetup_feedback.dart';

void main() {
  final fixedDate = DateTime(2024, 1, 1, 12, 0, 0);

  group('MeetupFeedback', () {
    group('fromMap', () {
      test('creates MeetupFeedback from valid map', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('feedback').doc('test').set({
          'id': 'feedback-123',
          'hangoutId': 'hangout-123',
          'userId': 'user-123',
          'didMeetup': true,
          'additionalFeedback': 'Great time!',
          'submittedAt': Timestamp.fromDate(fixedDate),
        });

        final doc = await firestore.collection('feedback').doc('test').get();
        final feedback = MeetupFeedback.fromMap(doc.data()!);

        expect(feedback.id, 'feedback-123');
        expect(feedback.hangoutId, 'hangout-123');
        expect(feedback.userId, 'user-123');
        expect(feedback.didMeetup, true);
        expect(feedback.additionalFeedback, 'Great time!');
        expect(feedback.submittedAt, fixedDate);
      });

      test('handles missing optional additionalFeedback', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('feedback').doc('test').set({
          'id': 'feedback-123',
          'hangoutId': 'hangout-123',
          'userId': 'user-123',
          'didMeetup': false,
          'submittedAt': Timestamp.fromDate(fixedDate),
        });

        final doc = await firestore.collection('feedback').doc('test').get();
        final feedback = MeetupFeedback.fromMap(doc.data()!);

        expect(feedback.additionalFeedback, isNull);
        expect(feedback.didMeetup, false);
      });

      test('handles null values with defaults', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('feedback').doc('test').set({
          'id': null,
          'hangoutId': null,
          'userId': null,
          'didMeetup': null,
          'submittedAt': Timestamp.fromDate(fixedDate),
        });

        final doc = await firestore.collection('feedback').doc('test').get();
        final feedback = MeetupFeedback.fromMap(doc.data()!);

        expect(feedback.id, '');
        expect(feedback.hangoutId, '');
        expect(feedback.userId, '');
        expect(feedback.didMeetup, false);
      });
    });

    group('toMap', () {
      test('converts MeetupFeedback to map correctly', () {
        final feedback = MeetupFeedback(
          id: 'feedback-123',
          hangoutId: 'hangout-123',
          userId: 'user-123',
          didMeetup: true,
          additionalFeedback: 'Great!',
          submittedAt: fixedDate,
        );

        final map = feedback.toMap();

        expect(map['id'], 'feedback-123');
        expect(map['hangoutId'], 'hangout-123');
        expect(map['userId'], 'user-123');
        expect(map['didMeetup'], true);
        expect(map['additionalFeedback'], 'Great!');
        expect(map['submittedAt'], isA<Timestamp>());
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = MeetupFeedback(
          id: 'feedback-123',
          hangoutId: 'hangout-123',
          userId: 'user-123',
          didMeetup: false,
          submittedAt: fixedDate,
        );

        final copy = original.copyWith(
          didMeetup: true,
          additionalFeedback: 'Changed my mind, it was great!',
        );

        expect(copy.didMeetup, true);
        expect(copy.additionalFeedback, 'Changed my mind, it was great!');
        expect(copy.id, original.id);
        expect(copy.hangoutId, original.hangoutId);
      });
    });
  });

  group('PendingFeedbackPrompt', () {
    group('fromMap', () {
      test('creates PendingFeedbackPrompt from valid map', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('prompts').doc('test').set({
          'id': 'prompt-123',
          'hangoutId': 'hangout-123',
          'userId': 'user-123',
          'hangoutCompletedAt': Timestamp.fromDate(fixedDate),
          'createdAt': Timestamp.fromDate(fixedDate),
          'isShown': false,
          'shownAt': null,
        });

        final doc = await firestore.collection('prompts').doc('test').get();
        final prompt = PendingFeedbackPrompt.fromMap(doc.data()!);

        expect(prompt.id, 'prompt-123');
        expect(prompt.hangoutId, 'hangout-123');
        expect(prompt.userId, 'user-123');
        expect(prompt.hangoutCompletedAt, fixedDate);
        expect(prompt.createdAt, fixedDate);
        expect(prompt.isShown, false);
        expect(prompt.shownAt, isNull);
      });

      test('handles shown prompt with shownAt timestamp', () async {
        final shownAt = fixedDate.add(const Duration(hours: 1));
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('prompts').doc('test').set({
          'id': 'prompt-123',
          'hangoutId': 'hangout-123',
          'userId': 'user-123',
          'hangoutCompletedAt': Timestamp.fromDate(fixedDate),
          'createdAt': Timestamp.fromDate(fixedDate),
          'isShown': true,
          'shownAt': Timestamp.fromDate(shownAt),
        });

        final doc = await firestore.collection('prompts').doc('test').get();
        final prompt = PendingFeedbackPrompt.fromMap(doc.data()!);

        expect(prompt.isShown, true);
        expect(prompt.shownAt, shownAt);
      });
    });

    group('toMap', () {
      test('converts PendingFeedbackPrompt to map correctly', () {
        final prompt = PendingFeedbackPrompt(
          id: 'prompt-123',
          hangoutId: 'hangout-123',
          userId: 'user-123',
          hangoutCompletedAt: fixedDate,
          createdAt: fixedDate,
          isShown: false,
        );

        final map = prompt.toMap();

        expect(map['id'], 'prompt-123');
        expect(map['hangoutId'], 'hangout-123');
        expect(map['userId'], 'user-123');
        expect(map['hangoutCompletedAt'], isA<Timestamp>());
        expect(map['createdAt'], isA<Timestamp>());
        expect(map['isShown'], false);
        expect(map['shownAt'], isNull);
      });

      test('includes shownAt when set', () {
        final shownAt = fixedDate.add(const Duration(hours: 1));
        final prompt = PendingFeedbackPrompt(
          id: 'prompt-123',
          hangoutId: 'hangout-123',
          userId: 'user-123',
          hangoutCompletedAt: fixedDate,
          createdAt: fixedDate,
          isShown: true,
          shownAt: shownAt,
        );

        final map = prompt.toMap();

        expect(map['isShown'], true);
        expect(map['shownAt'], isA<Timestamp>());
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = PendingFeedbackPrompt(
          id: 'prompt-123',
          hangoutId: 'hangout-123',
          userId: 'user-123',
          hangoutCompletedAt: fixedDate,
          createdAt: fixedDate,
          isShown: false,
        );

        final shownAt = fixedDate.add(const Duration(hours: 1));
        final copy = original.copyWith(
          isShown: true,
          shownAt: shownAt,
        );

        expect(copy.isShown, true);
        expect(copy.shownAt, shownAt);
        expect(copy.id, original.id);
        expect(copy.hangoutId, original.hangoutId);
      });
    });
  });
}
