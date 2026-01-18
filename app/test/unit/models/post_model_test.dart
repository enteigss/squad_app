import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:squad_app/models/post_model.dart';

void main() {
  group('Post', () {
    final fixedDate = DateTime(2024, 1, 1, 12, 0, 0);
    final futureDate = DateTime(2024, 1, 2, 14, 0, 0);

    Post createTestPost({
      String id = 'post-123',
      PostType type = PostType.waving,
      Activity? activity = Activity.diningHall,
      String? description = 'Test post',
      String authorId = 'user-123',
      String authorName = 'Test User',
      PostStatus status = PostStatus.upcoming,
      List<String> participantIds = const ['user-123'],
      String? location = 'Marciano Commons',
      List<String> genderPreferences = const ['Anyone'],
      bool deleted = false,
      bool isLocked = false,
      DateTime? scheduledTime,
    }) {
      return Post(
        id: id,
        type: type,
        activity: activity,
        description: description,
        authorId: authorId,
        authorName: authorName,
        createdAt: fixedDate,
        scheduledTime: scheduledTime ?? futureDate,
        status: status,
        participantIds: participantIds,
        location: location,
        genderPreferences: genderPreferences,
        deleted: deleted,
        isLocked: isLocked,
      );
    }

    group('fromMap', () {
      test('creates Post from valid map with Timestamp', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('posts').doc('test').set({
          'id': 'post-123',
          'type': 'waving',
          'activity': 'diningHall',
          'description': 'Test post',
          'authorId': 'user-123',
          'authorName': 'Test User',
          'authorDorm': 'Warren Towers',
          'authorYear': '2025',
          'createdAt': Timestamp.fromDate(fixedDate),
          'scheduledTime': Timestamp.fromDate(futureDate),
          'status': 'upcoming',
          'participantIds': ['user-123', 'user-456'],
          'location': 'Marciano Commons',
          'locationTo': 'GSU',
          'maxParticipants': 4,
          'genderPreferences': ['Anyone'],
          'deleted': false,
          'isLocked': false,
          'feedbackCollected': false,
        });

        final doc = await firestore.collection('posts').doc('test').get();
        final post = Post.fromMap(doc.data()!);

        expect(post.id, 'post-123');
        expect(post.type, PostType.waving);
        expect(post.activity, Activity.diningHall);
        expect(post.description, 'Test post');
        expect(post.authorId, 'user-123');
        expect(post.authorName, 'Test User');
        expect(post.authorDorm, 'Warren Towers');
        expect(post.authorYear, '2025');
        expect(post.status, PostStatus.upcoming);
        expect(post.participantIds, ['user-123', 'user-456']);
        expect(post.location, 'Marciano Commons');
        expect(post.locationTo, 'GSU');
        expect(post.maxParticipants, 4);
        expect(post.genderPreferences, ['Anyone']);
        expect(post.deleted, false);
        expect(post.isLocked, false);
      });

      test('handles all PostType values', () async {
        final firestore = FakeFirebaseFirestore();

        for (final type in PostType.values) {
          await firestore.collection('posts').doc(type.name).set({
            'id': type.name,
            'type': type.name,
            'authorId': 'user-123',
            'authorName': 'Test',
            'createdAt': Timestamp.fromDate(fixedDate),
            'status': 'upcoming',
            'participantIds': [],
          });

          final doc = await firestore.collection('posts').doc(type.name).get();
          final post = Post.fromMap(doc.data()!);
          expect(post.type, type);
        }
      });

      test('handles all Activity values', () async {
        final firestore = FakeFirebaseFirestore();

        for (final activity in Activity.values) {
          await firestore.collection('posts').doc(activity.name).set({
            'id': activity.name,
            'type': 'waving',
            'activity': activity.name,
            'authorId': 'user-123',
            'authorName': 'Test',
            'createdAt': Timestamp.fromDate(fixedDate),
            'status': 'upcoming',
            'participantIds': [],
          });

          final doc =
              await firestore.collection('posts').doc(activity.name).get();
          final post = Post.fromMap(doc.data()!);
          expect(post.activity, activity);
        }
      });

      test('handles all PostStatus values', () async {
        final firestore = FakeFirebaseFirestore();

        for (final status in PostStatus.values) {
          await firestore.collection('posts').doc(status.name).set({
            'id': status.name,
            'type': 'waving',
            'authorId': 'user-123',
            'authorName': 'Test',
            'createdAt': Timestamp.fromDate(fixedDate),
            'status': status.name,
            'participantIds': [],
          });

          final doc =
              await firestore.collection('posts').doc(status.name).get();
          final post = Post.fromMap(doc.data()!);
          expect(post.status, status);
        }
      });

      test('handles invalid enum values with defaults', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('posts').doc('test').set({
          'id': 'post-123',
          'type': 'invalid_type',
          'activity': 'invalid_activity',
          'status': 'invalid_status',
          'authorId': 'user-123',
          'authorName': 'Test',
          'createdAt': Timestamp.fromDate(fixedDate),
          'participantIds': [],
        });

        final doc = await firestore.collection('posts').doc('test').get();
        final post = Post.fromMap(doc.data()!);

        expect(post.type, PostType.waving);
        expect(post.activity, Activity.other);
        expect(post.status, PostStatus.upcoming);
      });

      test('handles null activity', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('posts').doc('test').set({
          'id': 'post-123',
          'type': 'walking',
          'activity': null,
          'authorId': 'user-123',
          'authorName': 'Test',
          'createdAt': Timestamp.fromDate(fixedDate),
          'status': 'upcoming',
          'participantIds': [],
        });

        final doc = await firestore.collection('posts').doc('test').get();
        final post = Post.fromMap(doc.data()!);

        expect(post.activity, isNull);
      });
    });

    group('toMap', () {
      test('converts Post to map correctly', () {
        final post = Post(
          id: 'post-123',
          type: PostType.waving,
          activity: Activity.diningHall,
          customActivity: null,
          description: 'Test post',
          authorId: 'user-123',
          authorName: 'Test User',
          authorDorm: 'Warren',
          authorYear: '2025',
          createdAt: fixedDate,
          scheduledTime: futureDate,
          status: PostStatus.upcoming,
          participantIds: ['user-123'],
          location: 'Marciano',
          locationTo: 'GSU',
          maxParticipants: 4,
          genderPreferences: ['Anyone'],
          deleted: false,
          isLocked: false,
          feedbackCollected: false,
        );

        final map = post.toMap();

        expect(map['id'], 'post-123');
        expect(map['type'], 'waving');
        expect(map['activity'], 'diningHall');
        expect(map['description'], 'Test post');
        expect(map['authorId'], 'user-123');
        expect(map['authorName'], 'Test User');
        expect(map['authorDorm'], 'Warren');
        expect(map['authorYear'], '2025');
        expect(map['status'], 'upcoming');
        expect(map['participantIds'], ['user-123']);
        expect(map['location'], 'Marciano');
        expect(map['locationTo'], 'GSU');
        expect(map['maxParticipants'], 4);
        expect(map['genderPreferences'], ['Anyone']);
        expect(map['deleted'], false);
        expect(map['isLocked'], false);
        expect(map['feedbackCollected'], false);
        expect(map['createdAt'], isA<Timestamp>());
        expect(map['scheduledTime'], isA<Timestamp>());
      });

      test('handles null scheduledTime', () {
        final post = Post(
          id: 'post-123',
          type: PostType.waving,
          authorId: 'user-123',
          authorName: 'Test',
          createdAt: fixedDate,
          status: PostStatus.upcoming,
          participantIds: [],
        );

        final map = post.toMap();

        expect(map['scheduledTime'], isNull);
      });

      test('includes customActivity when set', () {
        final post = Post(
          id: 'post-123',
          type: PostType.waving,
          activity: Activity.other,
          customActivity: 'Board games',
          authorId: 'user-123',
          authorName: 'Test',
          createdAt: fixedDate,
          status: PostStatus.upcoming,
          participantIds: [],
        );

        final map = post.toMap();

        expect(map['activity'], 'other');
        expect(map['customActivity'], 'Board games');
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = createTestPost();
        final copy = original.copyWith(
          description: 'Updated description',
          status: PostStatus.ongoing,
          isLocked: true,
        );

        expect(copy.description, 'Updated description');
        expect(copy.status, PostStatus.ongoing);
        expect(copy.isLocked, true);
        expect(copy.id, original.id);
        expect(copy.authorId, original.authorId);
        expect(copy.type, original.type);
      });

      test('can update participantIds', () {
        final original = createTestPost();
        final copy = original.copyWith(
          participantIds: ['user-123', 'user-456', 'user-789'],
        );

        expect(copy.participantIds, ['user-123', 'user-456', 'user-789']);
      });

      test('can update genderPreferences', () {
        final original = createTestPost();
        final copy = original.copyWith(
          genderPreferences: ['female'],
        );

        expect(copy.genderPreferences, ['female']);
      });
    });

    group('dynamicStatus', () {
      test('returns upcoming when scheduledTime is in the future', () {
        final now = DateTime.now();
        final post = Post(
          id: 'post-123',
          type: PostType.waving,
          authorId: 'user-123',
          authorName: 'Test',
          createdAt: now,
          scheduledTime: now.add(const Duration(hours: 2)),
          status: PostStatus.upcoming,
          participantIds: [],
        );

        expect(post.dynamicStatus, PostStatus.upcoming);
      });

      test('returns ongoing when scheduledTime is within last 4 hours', () {
        final now = DateTime.now();
        final post = Post(
          id: 'post-123',
          type: PostType.waving,
          authorId: 'user-123',
          authorName: 'Test',
          createdAt: now.subtract(const Duration(hours: 2)),
          scheduledTime: now.subtract(const Duration(hours: 1)),
          status: PostStatus.upcoming,
          participantIds: [],
        );

        expect(post.dynamicStatus, PostStatus.ongoing);
      });

      test('returns completed when scheduledTime is more than 4 hours ago',
          () {
        final now = DateTime.now();
        final post = Post(
          id: 'post-123',
          type: PostType.waving,
          authorId: 'user-123',
          authorName: 'Test',
          createdAt: now.subtract(const Duration(hours: 6)),
          scheduledTime: now.subtract(const Duration(hours: 5)),
          status: PostStatus.upcoming,
          participantIds: [],
        );

        expect(post.dynamicStatus, PostStatus.completed);
      });

      test('returns stored status when scheduledTime is null', () {
        final post = Post(
          id: 'post-123',
          type: PostType.waving,
          authorId: 'user-123',
          authorName: 'Test',
          createdAt: fixedDate,
          scheduledTime: null,
          status: PostStatus.ongoing,
          participantIds: [],
        );

        expect(post.dynamicStatus, PostStatus.ongoing);
      });
    });

    group('edge cases', () {
      test('handles deleted post', () {
        final post = createTestPost(deleted: true);
        expect(post.deleted, true);
      });

      test('handles locked post', () {
        final post = createTestPost(isLocked: true);
        expect(post.isLocked, true);
      });

      test('handles walking type with locationTo', () {
        final post = Post(
          id: 'post-123',
          type: PostType.walking,
          authorId: 'user-123',
          authorName: 'Test',
          createdAt: fixedDate,
          status: PostStatus.upcoming,
          participantIds: [],
          location: 'CAS',
          locationTo: 'GSU',
        );

        expect(post.type, PostType.walking);
        expect(post.location, 'CAS');
        expect(post.locationTo, 'GSU');
      });

      test('handles gender-restricted post', () {
        final post =
            createTestPost(genderPreferences: ['female', 'non-binary']);

        expect(post.genderPreferences, ['female', 'non-binary']);
      });
    });
  });
}
