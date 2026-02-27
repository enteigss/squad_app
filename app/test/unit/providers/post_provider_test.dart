import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_app/models/post_model.dart';
import 'package:squad_app/providers/post_provider.dart';
import 'package:squad_app/services/post_service.dart';
import 'package:squad_app/services/block_service.dart';

import '../../fixtures/post_fixtures.dart';
import '../../fixtures/user_fixtures.dart';
import 'post_provider_test.mocks.dart';

@GenerateMocks([PostService, BlockService])
void main() {
  group('PostProvider', () {
    late PostProvider provider;
    late MockPostService mockPostService;
    late MockBlockService mockBlockService;

    // Stream controllers to simulate real-time Firestore updates
    late StreamController<List<Post>> postsController;
    late StreamController<List<Post>> allPostsController;
    late StreamController<List<Post>> upcomingController;
    late StreamController<List<Post>> ongoingController;

    setUp(() {
      mockPostService = MockPostService();
      mockBlockService = MockBlockService();

      postsController = StreamController<List<Post>>.broadcast();
      allPostsController = StreamController<List<Post>>.broadcast();
      upcomingController = StreamController<List<Post>>.broadcast();
      ongoingController = StreamController<List<Post>>.broadcast();

      // Default stream stubs
      when(mockPostService.getPosts())
          .thenAnswer((_) => postsController.stream);
      when(mockPostService.getAllPosts())
          .thenAnswer((_) => allPostsController.stream);
      when(mockPostService.getUpcomingPosts())
          .thenAnswer((_) => upcomingController.stream);
      when(mockPostService.getOngoingPosts())
          .thenAnswer((_) => ongoingController.stream);
      when(mockPostService.updatePostStatuses())
          .thenAnswer((_) async {});

      // Default block service stubs — no blocking
      when(mockBlockService.shouldFilterContent(any, any, any))
          .thenReturn(false);
      when(mockBlockService.shouldHideHangoutFromBlocked(any, any, any))
          .thenReturn(false);

      provider = PostProvider(
        postService: mockPostService,
        blockService: mockBlockService,
        firestore: FakeFirebaseFirestore(),
      );
    });

    tearDown(() {
      provider.dispose();
      postsController.close();
      allPostsController.close();
      upcomingController.close();
      ongoingController.close();
    });

    /// Helper: initialize and pump streams with data
    Future<void> initializeWithPosts({
      List<Post>? posts,
      List<Post>? allPosts,
      List<Post>? upcoming,
      List<Post>? ongoing,
    }) async {
      await provider.initialize();

      if (posts != null) postsController.add(posts);
      if (allPosts != null) allPostsController.add(allPosts);
      if (upcoming != null) upcomingController.add(upcoming);
      if (ongoing != null) ongoingController.add(ongoing);

      // Let microtasks settle so listeners fire
      await Future.delayed(Duration.zero);
    }

    // ── Loading posts ───────────────────────────────────────────────────

    group('loading posts', () {
      test('initialize subscribes to all post streams', () async {
        await provider.initialize();

        verify(mockPostService.getPosts()).called(1);
        verify(mockPostService.getAllPosts()).called(1);
        verify(mockPostService.getUpcomingPosts()).called(1);
        verify(mockPostService.getOngoingPosts()).called(1);
      });

      test('posts getter returns data after stream emits', () async {
        await initializeWithPosts(
          posts: [PostFixtures.upcomingPost],
        );

        expect(provider.posts.length, 1);
        expect(provider.posts.first.id, PostFixtures.upcomingPost.id);
      });

      test('isLoading transitions from true to false during initialize',
          () async {
        // Before initialize, not loading
        expect(provider.isLoading, false);

        await provider.initialize();

        // After initialize completes, loading is done
        expect(provider.isLoading, false);
      });
    });

    // ── Real-time listener updates ──────────────────────────────────────

    group('real-time listener updates', () {
      test('posts update when stream emits new data', () async {
        await initializeWithPosts(posts: [PostFixtures.upcomingPost]);
        expect(provider.posts.length, 1);

        // Emit new data
        postsController.add([
          PostFixtures.upcomingPost,
          PostFixtures.ongoingPost,
        ]);
        await Future.delayed(Duration.zero);

        expect(provider.posts.length, 2);
      });

      test('upcoming posts update independently', () async {
        await initializeWithPosts(
          upcoming: [PostFixtures.upcomingPost],
        );

        expect(provider.upcomingPosts.length, 1);

        upcomingController.add([]);
        await Future.delayed(Duration.zero);

        expect(provider.upcomingPosts.length, 0);
      });

      test('ongoing posts update independently', () async {
        await initializeWithPosts(
          ongoing: [PostFixtures.ongoingPost],
        );

        expect(provider.ongoingPosts.length, 1);
      });
    });

    // ── Filtering by blocked users ──────────────────────────────────────

    group('filtering by blocked users', () {
      test('filters out posts from blocked users', () async {
        final blockedAuthorPost = PostFixtures.custom(
          id: 'blocked-post',
          authorId: 'blocked-author',
          authorName: 'Blocked Author',
        );

        // Make shouldFilterContent return true for the blocked author
        when(mockBlockService.shouldFilterContent(
          'blocked-author',
          any,
          any,
        )).thenReturn(true);

        await initializeWithPosts(
          posts: [PostFixtures.upcomingPost, blockedAuthorPost],
        );

        // Set current user to trigger filtering
        // ignore: deprecated_member_use_from_same_package
        provider.setCurrentUser(UserFixtures.basicUser);

        expect(provider.posts.length, 1);
        expect(provider.posts.first.id, PostFixtures.upcomingPost.id);
      });

      test('filters out posts where host blocked current user', () async {
        final hostBlockedPost = PostFixtures.custom(
          id: 'host-blocked-post',
          authorId: 'hostile-host',
          authorName: 'Hostile Host',
        );

        when(mockBlockService.shouldHideHangoutFromBlocked(
          'hostile-host',
          any,
          any,
        )).thenReturn(true);

        await initializeWithPosts(
          posts: [PostFixtures.upcomingPost, hostBlockedPost],
        );

        // ignore: deprecated_member_use_from_same_package
        provider.setCurrentUser(UserFixtures.basicUser);

        expect(provider.posts.length, 1);
        expect(provider.posts.first.id, PostFixtures.upcomingPost.id);
      });

      test('shows all posts when no user is set (no filtering)', () async {
        await initializeWithPosts(
          posts: [PostFixtures.upcomingPost, PostFixtures.ongoingPost],
        );

        expect(provider.posts.length, 2);
      });

      test('block filtering applies to all post lists', () async {
        final blockedPost = PostFixtures.custom(
          id: 'blocked-post',
          authorId: 'blocked-author',
          authorName: 'Blocked Author',
        );

        when(mockBlockService.shouldFilterContent(
          'blocked-author',
          any,
          any,
        )).thenReturn(true);

        await initializeWithPosts(
          posts: [blockedPost],
          allPosts: [blockedPost],
          upcoming: [blockedPost],
          ongoing: [blockedPost],
        );

        // ignore: deprecated_member_use_from_same_package
        provider.setCurrentUser(UserFixtures.basicUser);

        expect(provider.posts, isEmpty);
        expect(provider.allPosts, isEmpty);
        expect(provider.upcomingPosts, isEmpty);
        expect(provider.ongoingPosts, isEmpty);
      });
    });

    // ── Filtering by gender preferences ─────────────────────────────────

    group('filtering by gender preferences', () {
      test('getPostsForUser returns posts matching user gender', () async {
        final menPost = PostFixtures.custom(
          id: 'men-post',
          genderPreferences: ['Men'],
        );
        final womenPost = PostFixtures.custom(
          id: 'women-post',
          genderPreferences: ['Women'],
        );

        await initializeWithPosts(posts: [menPost, womenPost]);

        final result = provider.getPostsForUser('man');

        expect(result.any((p) => p.id == 'men-post'), true);
        expect(result.any((p) => p.id == 'women-post'), false);
      });

      test('getUpcomingPostsForUser filters by gender', () async {
        final allGenderPost = PostFixtures.custom(
          id: 'all-gender',
          genderPreferences: ['Men', 'Women', 'Non-binary'],
        );
        final womenOnlyPost = PostFixtures.custom(
          id: 'women-only',
          genderPreferences: ['Women'],
        );

        await initializeWithPosts(
          upcoming: [allGenderPost, womenOnlyPost],
        );

        final result = provider.getUpcomingPostsForUser('man');

        expect(result.length, 1);
        expect(result.first.id, 'all-gender');
      });

      test('getOngoingPostsForUser filters by gender', () async {
        final menPost = PostFixtures.custom(
          id: 'men-ongoing',
          genderPreferences: ['Men'],
        );

        await initializeWithPosts(ongoing: [menPost]);

        final result = provider.getOngoingPostsForUser('woman');

        expect(result, isEmpty);
      });

      test('null gender only sees all-inclusive posts', () async {
        final allInclusive = PostFixtures.custom(
          id: 'all-inclusive',
          genderPreferences: ['Men', 'Women', 'Non-binary'],
        );
        final menOnly = PostFixtures.custom(
          id: 'men-only',
          genderPreferences: ['Men'],
        );

        await initializeWithPosts(posts: [allInclusive, menOnly]);

        final result = provider.getPostsForUser(null);

        expect(result.length, 1);
        expect(result.first.id, 'all-inclusive');
      });
    });

    // ── createPost ──────────────────────────────────────────────────────

    group('createPost', () {
      test('delegates to PostService and returns true on success', () async {
        when(mockPostService.createPost(any))
            .thenAnswer((_) async => 'new-post-id');

        final result = await provider.createPost(
          type: PostType.waving,
          authorId: 'user-123',
          authorName: 'Test User',
          genderPreferences: ['Men', 'Women', 'Non-binary'],
          description: 'Test post',
        );

        expect(result, true);
        expect(provider.lastCreatedPostId, 'new-post-id');
        verify(mockPostService.createPost(any)).called(1);
      });

      test('returns false and sets error on failure', () async {
        when(mockPostService.createPost(any))
            .thenThrow(Exception('Network error'));

        final result = await provider.createPost(
          type: PostType.waving,
          authorId: 'user-123',
          authorName: 'Test User',
          genderPreferences: ['Anyone'],
        );

        expect(result, false);
        expect(provider.error, isNotNull);
        expect(provider.error, contains('Failed to create post'));
      });

      test('sets ongoing status when scheduledTime is now', () async {
        when(mockPostService.createPost(any))
            .thenAnswer((_) async => 'post-id');

        await provider.createPost(
          type: PostType.waving,
          authorId: 'user-123',
          authorName: 'Test User',
          genderPreferences: ['Anyone'],
          scheduledTime: null, // null = now
        );

        final captured =
            verify(mockPostService.createPost(captureAny)).captured.single
                as Post;
        expect(captured.status, PostStatus.ongoing);
      });

      test('sets upcoming status when scheduledTime is in the future',
          () async {
        when(mockPostService.createPost(any))
            .thenAnswer((_) async => 'post-id');

        await provider.createPost(
          type: PostType.waving,
          authorId: 'user-123',
          authorName: 'Test User',
          genderPreferences: ['Anyone'],
          scheduledTime: DateTime.now().add(const Duration(hours: 2)),
        );

        final captured =
            verify(mockPostService.createPost(captureAny)).captured.single
                as Post;
        expect(captured.status, PostStatus.upcoming);
      });
    });

    // ── joinPost / leavePost ────────────────────────────────────────────

    group('joinPost', () {
      test('delegates to PostService and returns true', () async {
        when(mockPostService.joinPost(any, any)).thenAnswer((_) async {});

        final result = await provider.joinPost('post-123', 'user-123');

        expect(result, true);
        verify(mockPostService.joinPost('post-123', 'user-123')).called(1);
      });

      test('returns false and sets error on failure', () async {
        when(mockPostService.joinPost(any, any))
            .thenThrow(Exception('Post is full'));

        final result = await provider.joinPost('post-123', 'user-123');

        expect(result, false);
        expect(provider.error, contains('Failed to join post'));
      });
    });

    group('leavePost', () {
      test('delegates to PostService and returns true', () async {
        when(mockPostService.leavePost(any, any)).thenAnswer((_) async {});

        final result = await provider.leavePost('post-123', 'user-123');

        expect(result, true);
        verify(mockPostService.leavePost('post-123', 'user-123')).called(1);
      });

      test('returns false and sets error on failure', () async {
        when(mockPostService.leavePost(any, any))
            .thenThrow(Exception('Not a participant'));

        final result = await provider.leavePost('post-123', 'user-123');

        expect(result, false);
        expect(provider.error, contains('Failed to leave post'));
      });
    });

    // ── canUserJoinPost ─────────────────────────────────────────────────

    group('canUserJoinPost', () {
      test('returns true when user can join', () {
        final post = PostFixtures.upcomingPost.copyWith(
          participantIds: ['author-id'],
          maxParticipants: 4,
          genderPreferences: ['Men', 'Women', 'Non-binary'],
          scheduledTime: DateTime.now().add(const Duration(hours: 2)),
        );

        expect(
          provider.canUserJoinPost(post, 'new-user', userGender: 'man'),
          true,
        );
      });

      test('returns false when user already joined', () {
        final post = PostFixtures.upcomingPost.copyWith(
          participantIds: ['user-123'],
        );

        expect(provider.canUserJoinPost(post, 'user-123'), false);
      });

      test('returns false when post is full', () {
        final post = PostFixtures.upcomingPost.copyWith(
          participantIds: ['u1', 'u2', 'u3', 'u4'],
          maxParticipants: 4,
        );

        expect(provider.canUserJoinPost(post, 'new-user'), false);
      });

      test('returns false when gender does not match', () {
        final post = PostFixtures.upcomingPost.copyWith(
          participantIds: ['author-id'],
          genderPreferences: ['Women'],
          scheduledTime: DateTime.now().add(const Duration(hours: 2)),
        );

        expect(
          provider.canUserJoinPost(post, 'new-user', userGender: 'man'),
          false,
        );
      });
    });

    // ── getPostById ─────────────────────────────────────────────────────

    group('getPostById', () {
      test('returns post from allPosts list', () async {
        await initializeWithPosts(
          allPosts: [PostFixtures.upcomingPost],
        );

        final result = provider.getPostById(PostFixtures.upcomingPost.id);

        expect(result, isNotNull);
        expect(result!.id, PostFixtures.upcomingPost.id);
      });

      test('returns null when post is not found', () async {
        await initializeWithPosts(allPosts: []);

        final result = provider.getPostById('nonexistent');

        expect(result, isNull);
      });
    });

    // ── Error handling ──────────────────────────────────────────────────

    group('error handling', () {
      test('updatePost sets error on failure', () async {
        when(mockPostService.updatePost(any))
            .thenThrow(Exception('Update failed'));

        final result =
            await provider.updatePost(PostFixtures.upcomingPost);

        expect(result, false);
        expect(provider.error, contains('Failed to update post'));
      });

      test('deletePost sets error on failure', () async {
        when(mockPostService.deletePost(any))
            .thenThrow(Exception('Delete failed'));

        final result = await provider.deletePost('post-123');

        expect(result, false);
        expect(provider.error, contains('Failed to delete post'));
      });

      test('error is cleared before new operations', () async {
        // First, trigger an error
        when(mockPostService.createPost(any))
            .thenThrow(Exception('first error'));
        await provider.createPost(
          type: PostType.waving,
          authorId: 'user-123',
          authorName: 'Test',
          genderPreferences: ['Anyone'],
        );
        expect(provider.error, isNotNull);

        // Now succeed - error should be cleared
        when(mockPostService.createPost(any))
            .thenAnswer((_) async => 'id');
        await provider.createPost(
          type: PostType.waving,
          authorId: 'user-123',
          authorName: 'Test',
          genderPreferences: ['Anyone'],
        );
        expect(provider.error, isNull);
      });

      test('stream error sets provider error', () async {
        await provider.initialize();

        postsController.addError('Stream failed');
        await Future.delayed(Duration.zero);

        expect(provider.error, contains('Failed to load posts'));
      });
    });

    // ── cleanup ─────────────────────────────────────────────────────────

    group('cleanup', () {
      test('clears all state', () async {
        await initializeWithPosts(
          posts: [PostFixtures.upcomingPost],
          allPosts: [PostFixtures.upcomingPost],
          upcoming: [PostFixtures.upcomingPost],
          ongoing: [PostFixtures.ongoingPost],
        );

        provider.cleanup();

        expect(provider.posts, isEmpty);
        expect(provider.allPosts, isEmpty);
        expect(provider.upcomingPosts, isEmpty);
        expect(provider.ongoingPosts, isEmpty);
        expect(provider.isLoading, false);
        expect(provider.error, isNull);
      });
    });
  });
}
