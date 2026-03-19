import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_app/models/post_model.dart';
import 'package:squad_app/services/post_service.dart';
import 'package:squad_app/services/chat_service.dart';
import 'package:squad_app/services/firestore_service.dart';
import 'package:squad_app/services/feedback_service.dart';
import 'package:squad_app/services/notification_service.dart';
import 'package:squad_app/services/analytics_service.dart';
import 'package:squad_app/models/chat_message.dart';

import '../../fixtures/post_fixtures.dart';
import '../../fixtures/user_fixtures.dart';
import 'post_service_test.mocks.dart';

@GenerateMocks([
  ChatService,
  FirestoreService,
  FeedbackService,
  AnalyticsService,
  NotificationService,
])
void main() {
  group('PostService', () {
    late PostService postService;
    late FakeFirebaseFirestore fakeFirestore;
    late MockChatService mockChatService;
    late MockFirestoreService mockFirestoreService;
    late MockFeedbackService mockFeedbackService;
    late MockAnalyticsService mockAnalyticsService;
    late MockNotificationService mockNotificationService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockChatService = MockChatService();
      mockFirestoreService = MockFirestoreService();
      mockFeedbackService = MockFeedbackService();
      mockAnalyticsService = MockAnalyticsService();
      mockNotificationService = MockNotificationService();

      // Default stubs for fire-and-forget calls
      when(mockChatService.initializeChat(any, any))
          .thenAnswer((_) async {});
      when(mockChatService.handleUserJoined(
        context: anyNamed('context'),
        chatRoomId: anyNamed('chatRoomId'),
        userName: anyNamed('userName'),
      )).thenAnswer((_) async {});
      when(mockChatService.handleUserLeft(
        context: anyNamed('context'),
        chatRoomId: anyNamed('chatRoomId'),
        userName: anyNamed('userName'),
      )).thenAnswer((_) async {});
      when(mockChatService.archiveChat(any, any))
          .thenAnswer((_) async {});
      when(mockFirestoreService.getUser(any))
          .thenAnswer((_) async => UserFixtures.basicUser);
      when(mockNotificationService.notifyHangoutOwnerOfJoin(
        hangoutId: anyNamed('hangoutId'),
        ownerId: anyNamed('ownerId'),
        joinerName: anyNamed('joinerName'),
        joinerId: anyNamed('joinerId'),
      )).thenAnswer((_) async {});
      when(mockNotificationService.notifyHangoutOwnerOfLeave(
        hangoutId: anyNamed('hangoutId'),
        ownerId: anyNamed('ownerId'),
        leaverName: anyNamed('leaverName'),
        leaverId: anyNamed('leaverId'),
      )).thenAnswer((_) async {});
      when(mockFeedbackService.createFeedbackPromptForAuthor(any))
          .thenAnswer((_) async {});

      postService = PostService(
        firestore: fakeFirestore,
        chatService: mockChatService,
        firestoreService: mockFirestoreService,
        feedbackService: mockFeedbackService,
        analyticsService: mockAnalyticsService,
        notificationService: mockNotificationService,
      );
    });

    /// Helper to seed a post directly into Firestore
    Future<void> seedPost(Post post) async {
      await fakeFirestore.collection('posts').doc(post.id).set(post.toMap());
    }

    /// Helper to seed a user into Firestore (needed for joinPost gender check)
    Future<void> seedUser(String userId, {String? gender}) async {
      await fakeFirestore.collection('users').doc(userId).set({
        ...UserFixtures.basicUser.toMap(),
        'id': userId,
        'gender': gender ?? 'man',
      });
    }

    // ── createPost ──────────────────────────────────────────────────────

    group('createPost', () {
      test('creates a post document in Firestore and returns generated id',
          () async {
        final post = PostFixtures.upcomingPost;

        final id = await postService.createPost(post);

        expect(id, isNotEmpty);

        final doc = await fakeFirestore.collection('posts').doc(id).get();
        expect(doc.exists, true);
        expect(doc.data()?['id'], id);
        expect(doc.data()?['description'], post.description);
        expect(doc.data()?['authorId'], post.authorId);
      });

      test('stores the post with all fields from the model', () async {
        final post = PostFixtures.customActivityPost;

        final id = await postService.createPost(post);

        final doc = await fakeFirestore.collection('posts').doc(id).get();
        final data = doc.data()!;
        expect(data['type'], post.type.name);
        expect(data['activity'], post.activity?.name);
        expect(data['customActivity'], post.customActivity);
        expect(data['location'], post.location);
        expect(data['maxParticipants'], post.maxParticipants);
      });

      test('initializes chat for the new post', () async {
        final post = PostFixtures.upcomingPost;

        final id = await postService.createPost(post);

        verify(mockChatService.initializeChat(ChatContext.hangout, id))
            .called(1);
      });
    });

    // ── getPost ─────────────────────────────────────────────────────────

    group('getPost', () {
      test('returns the post when it exists', () async {
        final post = PostFixtures.upcomingPost;
        await seedPost(post);

        final result = await postService.getPost(post.id);

        expect(result, isNotNull);
        expect(result!.id, post.id);
        expect(result.description, post.description);
        expect(result.authorId, post.authorId);
      });

      test('returns null when post does not exist', () async {
        final result = await postService.getPost('nonexistent-id');

        expect(result, isNull);
      });
    });

    // ── updatePost ──────────────────────────────────────────────────────

    group('updatePost', () {
      test('updates post data in Firestore', () async {
        final post = PostFixtures.upcomingPost;
        await seedPost(post);

        final updatedPost = post.copyWith(
          description: 'Updated description',
          location: 'New Location',
        );
        await postService.updatePost(updatedPost);

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        expect(doc.data()?['description'], 'Updated description');
        expect(doc.data()?['location'], 'New Location');
      });
    });

    // ── deletePost ──────────────────────────────────────────────────────

    group('deletePost', () {
      test('soft deletes by setting deleted flag to true', () async {
        final post = PostFixtures.upcomingPost;
        await seedPost(post);

        await postService.deletePost(post.id);

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        expect(doc.data()?['deleted'], true);
      });

      test('does not remove the document from Firestore', () async {
        final post = PostFixtures.upcomingPost;
        await seedPost(post);

        await postService.deletePost(post.id);

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        expect(doc.exists, true);
      });
    });

    // ── joinPost ────────────────────────────────────────────────────────

    group('joinPost', () {
      const joiningUserId = 'user-joining';

      test('adds user to participantIds', () async {
        final post = PostFixtures.upcomingPost.copyWith(
          genderPreferences: ['Men', 'Women', 'Non-binary'],
        );
        await seedPost(post);
        await seedUser(joiningUserId, gender: 'man');

        await postService.joinPost(post.id, joiningUserId);

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        final participants =
            List<String>.from(doc.data()?['participantIds'] ?? []);
        expect(participants, contains(joiningUserId));
      });

      test('throws when user already joined', () async {
        final post = PostFixtures.upcomingPost.copyWith(
          participantIds: ['user-123', joiningUserId],
          genderPreferences: ['Men', 'Women', 'Non-binary'],
        );
        await seedPost(post);
        await seedUser(joiningUserId, gender: 'man');

        await expectLater(
          () => postService.joinPost(post.id, joiningUserId),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('User already joined'),
            ),
          ),
        );
      });

      test('throws when post is full (maxParticipants reached)', () async {
        final post = PostFixtures.upcomingPost.copyWith(
          participantIds: ['user-1', 'user-2', 'user-3', 'user-4'],
          maxParticipants: 4,
          genderPreferences: ['Men', 'Women', 'Non-binary'],
        );
        await seedPost(post);
        await seedUser(joiningUserId, gender: 'man');

        await expectLater(
          () => postService.joinPost(post.id, joiningUserId),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Post is full'),
            ),
          ),
        );
      });

      test('throws when post does not exist', () async {
        await seedUser(joiningUserId, gender: 'man');

        await expectLater(
          () => postService.joinPost('nonexistent', joiningUserId),
          throwsA(isA<Exception>()),
        );
      });

      test('throws when gender preferences do not match', () async {
        final post = PostFixtures.upcomingPost.copyWith(
          genderPreferences: ['Women'],
        );
        await seedPost(post);
        await seedUser(joiningUserId, gender: 'man');

        await expectLater(
          () => postService.joinPost(post.id, joiningUserId),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Gender preferences do not match'),
            ),
          ),
        );
      });

      test('locks post when maxParticipants reached after join', () async {
        final post = PostFixtures.upcomingPost.copyWith(
          participantIds: ['user-123'],
          maxParticipants: 2,
          genderPreferences: ['Men', 'Women', 'Non-binary'],
        );
        await seedPost(post);
        await seedUser(joiningUserId, gender: 'man');

        await postService.joinPost(post.id, joiningUserId);

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        expect(doc.data()?['isLocked'], true);
      });

      test('does not lock post when no maxParticipants set', () async {
        final post = PostFixtures.upcomingPost.copyWith(
          participantIds: ['user-123'],
          genderPreferences: ['Men', 'Women', 'Non-binary'],
        );
        final map = post.toMap();
        map.remove('maxParticipants');
        await fakeFirestore.collection('posts').doc(post.id).set(map);
        await seedUser(joiningUserId, gender: 'man');

        await postService.joinPost(post.id, joiningUserId);

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        expect(doc.data()?['isLocked'], isNot(true));
      });

      test('allows woman to join Women-only post', () async {
        final post = PostFixtures.upcomingPost.copyWith(
          genderPreferences: ['Women'],
        );
        await seedPost(post);
        await seedUser(joiningUserId, gender: 'woman');

        await postService.joinPost(post.id, joiningUserId);

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        final participants =
            List<String>.from(doc.data()?['participantIds'] ?? []);
        expect(participants, contains(joiningUserId));
      });
    });

    // ── leavePost ───────────────────────────────────────────────────────

    group('leavePost', () {
      const leavingUserId = 'user-456';

      test('removes user from participantIds', () async {
        final post = PostFixtures.ongoingPost; // has user-456 as participant
        await seedPost(post);
        await seedUser(leavingUserId);

        await postService.leavePost(post.id, leavingUserId);

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        final participants =
            List<String>.from(doc.data()?['participantIds'] ?? []);
        expect(participants, isNot(contains(leavingUserId)));
      });

      test('throws when user is not a participant', () async {
        final post = PostFixtures.upcomingPost;
        await seedPost(post);

        await expectLater(
          () => postService.leavePost(post.id, 'not-a-participant'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('User is not a participant'),
            ),
          ),
        );
      });

      test('throws when post does not exist', () async {
        await expectLater(
          () => postService.leavePost('nonexistent', leavingUserId),
          throwsA(isA<Exception>()),
        );
      });

      test('unlocks post when participant count drops below max', () async {
        final post = PostFixtures.upcomingPost.copyWith(
          participantIds: ['user-123', leavingUserId],
          maxParticipants: 2,
          isLocked: true,
        );
        await seedPost(post);
        await seedUser(leavingUserId);

        await postService.leavePost(post.id, leavingUserId);

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        expect(doc.data()?['isLocked'], false);
      });

      test('keeps other participants after one leaves', () async {
        final post = PostFixtures.ongoingPost;
        await seedPost(post);
        await seedUser(leavingUserId);

        await postService.leavePost(post.id, leavingUserId);

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        final participants =
            List<String>.from(doc.data()?['participantIds'] ?? []);
        expect(participants, contains('user-123'));
      });
    });

    // ── updatePostStatuses ──────────────────────────────────────────────

    group('updatePostStatuses', () {
      test('transitions upcoming post to ongoing when time has passed',
          () async {
        final now = DateTime.now();
        final post = PostFixtures.upcomingPost.copyWith(
          scheduledTime: now.subtract(const Duration(hours: 1)),
          status: PostStatus.upcoming,
        );
        await seedPost(post);

        await postService.updatePostStatuses();

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        expect(doc.data()?['status'], PostStatus.ongoing.name);
      });

      test('transitions ongoing post to completed after 4 hours', () async {
        final now = DateTime.now();
        final post = PostFixtures.upcomingPost.copyWith(
          scheduledTime: now.subtract(const Duration(hours: 5)),
          status: PostStatus.ongoing,
        );
        await seedPost(post);

        await postService.updatePostStatuses();

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        expect(doc.data()?['status'], PostStatus.completed.name);
      });

      test('keeps upcoming status when scheduledTime is in the future',
          () async {
        final now = DateTime.now();
        final post = PostFixtures.upcomingPost.copyWith(
          scheduledTime: now.add(const Duration(hours: 2)),
          status: PostStatus.upcoming,
        );
        await seedPost(post);

        await postService.updatePostStatuses();

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        expect(doc.data()?['status'], PostStatus.upcoming.name);
      });

      test('skips deleted posts', () async {
        final now = DateTime.now();
        final post = PostFixtures.deletedPost.copyWith(
          scheduledTime: now.subtract(const Duration(hours: 5)),
          status: PostStatus.upcoming,
        );
        await seedPost(post);

        await postService.updatePostStatuses();

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        expect(doc.data()?['status'], PostStatus.upcoming.name);
      });

      test('does not update when status is already correct', () async {
        final now = DateTime.now();
        final post = PostFixtures.upcomingPost.copyWith(
          scheduledTime: now.add(const Duration(hours: 2)),
          status: PostStatus.upcoming,
        );
        await seedPost(post);

        await postService.updatePostStatuses();

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        expect(doc.data()?['status'], PostStatus.upcoming.name);
      });
    });

    // ── Query filtering ─────────────────────────────────────────────────

    group('query filtering', () {
      Future<void> seedMultiplePosts() async {
        final now = DateTime.now();

        await seedPost(PostFixtures.upcomingPost.copyWith(
          scheduledTime: now.add(const Duration(hours: 2)),
          status: PostStatus.upcoming,
        ));

        await seedPost(PostFixtures.ongoingPost.copyWith(
          scheduledTime: now.subtract(const Duration(hours: 1)),
          status: PostStatus.ongoing,
        ));

        await seedPost(PostFixtures.completedPost.copyWith(
          scheduledTime: now.subtract(const Duration(hours: 10)),
          status: PostStatus.completed,
        ));

        await seedPost(PostFixtures.deletedPost);
        await seedPost(PostFixtures.lockedPost);
      }

      test('getPosts excludes deleted and locked posts', () async {
        await seedMultiplePosts();

        final posts = await postService.getPosts().first;

        expect(posts.any((p) => p.deleted), false);
        expect(posts.any((p) => p.isLocked), false);
      });

      test('getAllPosts excludes deleted but includes locked', () async {
        await seedMultiplePosts();

        final posts = await postService.getAllPosts().first;

        expect(posts.any((p) => p.deleted), false);
        expect(posts.any((p) => p.isLocked), true);
      });

      test('getPostsByStatus filters by status', () async {
        await seedMultiplePosts();

        final upcomingPosts =
            await postService.getPostsByStatus(PostStatus.upcoming).first;

        for (final post in upcomingPosts) {
          expect(post.status, PostStatus.upcoming);
          expect(post.deleted, false);
          expect(post.isLocked, false);
        }
      });

      test('getUserPosts returns only posts by specific user', () async {
        await seedMultiplePosts();

        final userId = UserFixtures.secondUser.id;
        final userPosts = await postService.getUserPosts(userId).first;

        for (final post in userPosts) {
          expect(post.authorId, userId);
          expect(post.deleted, false);
        }
      });

      test('getPostsByGenderPreference filters for men', () async {
        await seedPost(PostFixtures.upcomingPost.copyWith(
          id: 'post-all',
          genderPreferences: ['Men', 'Women', 'Non-binary'],
        ));

        await seedPost(PostFixtures.upcomingPost.copyWith(
          id: 'post-women',
          genderPreferences: ['Women'],
        ));

        final posts =
            await postService.getPostsByGenderPreference('man').first;

        expect(posts.any((p) => p.id == 'post-all'), true);
        expect(posts.any((p) => p.id == 'post-women'), false);
      });

      test('getPostsByGenderPreference filters for women', () async {
        await seedPost(PostFixtures.upcomingPost.copyWith(
          id: 'post-all',
          genderPreferences: ['Men', 'Women', 'Non-binary'],
        ));

        await seedPost(PostFixtures.upcomingPost.copyWith(
          id: 'post-men',
          genderPreferences: ['Men'],
        ));

        final posts =
            await postService.getPostsByGenderPreference('woman').first;

        expect(posts.any((p) => p.id == 'post-all'), true);
        expect(posts.any((p) => p.id == 'post-men'), false);
      });

      test(
          'getPostsByGenderPreference with null gender shows only all-inclusive posts',
          () async {
        await seedPost(PostFixtures.upcomingPost.copyWith(
          id: 'post-all',
          genderPreferences: ['Men', 'Women', 'Non-binary'],
        ));

        await seedPost(PostFixtures.upcomingPost.copyWith(
          id: 'post-men',
          genderPreferences: ['Men'],
        ));

        final posts =
            await postService.getPostsByGenderPreference(null).first;

        expect(posts.any((p) => p.id == 'post-all'), true);
        expect(posts.any((p) => p.id == 'post-men'), false);
      });

      test('searchPosts filters by description', () async {
        await seedPost(PostFixtures.upcomingPost.copyWith(
          id: 'post-lunch',
          description: 'Looking for lunch buddies',
        ));

        await seedPost(PostFixtures.upcomingPost.copyWith(
          id: 'post-gym',
          description: 'Gym workout session',
        ));

        final results = await postService.searchPosts('lunch').first;

        expect(results.any((p) => p.id == 'post-lunch'), true);
        expect(results.any((p) => p.id == 'post-gym'), false);
      });

      test('searchPosts is case insensitive', () async {
        await seedPost(PostFixtures.upcomingPost.copyWith(
          id: 'post-study',
          description: 'STUDY SESSION at the library',
        ));

        final results = await postService.searchPosts('study').first;

        expect(results.any((p) => p.id == 'post-study'), true);
      });

      test('searchPosts excludes deleted and locked posts', () async {
        await seedPost(PostFixtures.deletedPost.copyWith(
          description: 'Deleted lunch plan',
        ));

        await seedPost(PostFixtures.lockedPost.copyWith(
          description: 'Locked lunch plan',
        ));

        final results = await postService.searchPosts('lunch').first;

        expect(results.any((p) => p.deleted), false);
        expect(results.any((p) => p.isLocked), false);
      });
    });

    // ── lockPost / unlockPost ───────────────────────────────────────────

    group('lockPost / unlockPost', () {
      test('lockPost sets isLocked to true', () async {
        final post = PostFixtures.upcomingPost;
        await seedPost(post);

        await postService.lockPost(post.id);

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        expect(doc.data()?['isLocked'], true);
      });

      test('unlockPost sets isLocked to false', () async {
        final post = PostFixtures.lockedPost;
        await seedPost(post);

        await postService.unlockPost(post.id);

        final doc =
            await fakeFirestore.collection('posts').doc(post.id).get();
        expect(doc.data()?['isLocked'], false);
      });
    });
  });
}
