import 'package:squad_app/models/post_model.dart';
import 'user_fixtures.dart';

/// Test fixtures for Post model
///
/// Usage:
/// ```dart
/// final post = PostFixtures.upcomingPost;
/// final completedPost = PostFixtures.completedPost;
/// ```
class PostFixtures {
  static final DateTime _fixedDate = DateTime(2024, 1, 1, 12, 0, 0);
  static final DateTime _futureDate = DateTime(2024, 1, 2, 14, 0, 0);

  /// An upcoming hangout post
  static Post get upcomingPost => Post(
        id: 'post-123',
        type: PostType.waving,
        activity: Activity.diningHall,
        description: 'Looking for people to grab lunch!',
        authorId: UserFixtures.basicUser.id,
        authorName: UserFixtures.basicUser.displayName!,
        authorDorm: 'Warren Towers',
        authorYear: '2025',
        createdAt: _fixedDate,
        scheduledTime: _futureDate,
        status: PostStatus.upcoming,
        participantIds: [UserFixtures.basicUser.id],
        location: 'Marciano Commons',
        maxParticipants: 4,
        genderPreferences: ['Anyone'],
      );

  /// An ongoing hangout post
  static Post get ongoingPost => Post(
        id: 'post-456',
        type: PostType.walking,
        activity: Activity.walking,
        description: 'Walking to class, anyone want to join?',
        authorId: UserFixtures.basicUser.id,
        authorName: UserFixtures.basicUser.displayName!,
        createdAt: _fixedDate,
        status: PostStatus.ongoing,
        participantIds: [UserFixtures.basicUser.id, UserFixtures.secondUser.id],
        location: 'CAS',
        locationTo: 'GSU',
        genderPreferences: ['Anyone'],
      );

  /// A completed hangout post
  static Post get completedPost => Post(
        id: 'post-789',
        type: PostType.waving,
        activity: Activity.studying,
        description: 'Study session at Mugar',
        authorId: UserFixtures.secondUser.id,
        authorName: UserFixtures.secondUser.displayName!,
        createdAt: _fixedDate.subtract(const Duration(days: 1)),
        status: PostStatus.completed,
        participantIds: [UserFixtures.secondUser.id, UserFixtures.basicUser.id],
        location: 'Mugar Library',
        feedbackCollected: true,
      );

  /// A post with custom activity
  static Post get customActivityPost => Post(
        id: 'post-custom',
        type: PostType.waving,
        activity: Activity.other,
        customActivity: 'Board game night',
        description: 'Playing Catan in the lounge',
        authorId: UserFixtures.basicUser.id,
        authorName: UserFixtures.basicUser.displayName!,
        createdAt: _fixedDate,
        scheduledTime: _futureDate,
        status: PostStatus.upcoming,
        participantIds: [UserFixtures.basicUser.id],
        location: 'Warren Towers Lounge',
        maxParticipants: 6,
      );

  /// A post restricted to specific gender
  static Post get genderRestrictedPost => Post(
        id: 'post-gender',
        type: PostType.waving,
        activity: Activity.fitRec,
        description: 'Gym session',
        authorId: UserFixtures.secondUser.id,
        authorName: UserFixtures.secondUser.displayName!,
        createdAt: _fixedDate,
        scheduledTime: _futureDate,
        status: PostStatus.upcoming,
        participantIds: [UserFixtures.secondUser.id],
        location: 'FitRec',
        genderPreferences: ['female'],
      );

  /// A locked post (no more participants allowed)
  static Post get lockedPost => Post(
        id: 'post-locked',
        type: PostType.waving,
        activity: Activity.chilling,
        description: 'Hanging out',
        authorId: UserFixtures.basicUser.id,
        authorName: UserFixtures.basicUser.displayName!,
        createdAt: _fixedDate,
        status: PostStatus.ongoing,
        participantIds: [UserFixtures.basicUser.id, UserFixtures.secondUser.id],
        isLocked: true,
      );

  /// A deleted post
  static Post get deletedPost => Post(
        id: 'post-deleted',
        type: PostType.waving,
        activity: Activity.diningHall,
        description: 'This was deleted',
        authorId: UserFixtures.basicUser.id,
        authorName: UserFixtures.basicUser.displayName!,
        createdAt: _fixedDate,
        status: PostStatus.upcoming,
        participantIds: [UserFixtures.basicUser.id],
        deleted: true,
      );

  /// Creates a custom post with specified overrides
  static Post custom({
    String? id,
    PostType? type,
    Activity? activity,
    String? description,
    String? authorId,
    String? authorName,
    PostStatus? status,
    List<String>? participantIds,
    List<String>? genderPreferences,
    bool? isLocked,
    bool? deleted,
  }) {
    return upcomingPost.copyWith(
      id: id,
      type: type,
      activity: activity,
      description: description,
      authorId: authorId,
      authorName: authorName,
      status: status,
      participantIds: participantIds,
      genderPreferences: genderPreferences,
      isLocked: isLocked,
      deleted: deleted,
    );
  }

  /// List of multiple posts for testing feeds
  static List<Post> get multiplePosts => [
        upcomingPost,
        ongoingPost,
        completedPost,
      ];

  /// Posts that should be filtered out (deleted or by blocked users)
  static List<Post> get postsToFilter => [
        deletedPost,
        Post(
          id: 'post-by-blocked',
          type: PostType.waving,
          activity: Activity.diningHall,
          description: 'Post by blocked user',
          authorId: 'user-blocked',
          authorName: 'Blocked User',
          createdAt: _fixedDate,
          status: PostStatus.upcoming,
          participantIds: ['user-blocked'],
        ),
      ];
}
