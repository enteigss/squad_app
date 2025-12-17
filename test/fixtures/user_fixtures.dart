import 'package:squad_app/models/user_model.dart';

/// Test fixtures for UserModel
///
/// Usage:
/// ```dart
/// final user = UserFixtures.basicUser;
/// final blockedUser = UserFixtures.blockedUser;
/// ```
class UserFixtures {
  static final DateTime _fixedDate = DateTime(2024, 1, 1, 12, 0, 0);

  /// A basic verified user with complete profile
  static UserModel get basicUser => UserModel(
        id: 'user-123',
        email: 'testuser@bu.edu',
        username: 'testuser',
        displayName: 'Test User',
        photoUrl: 'https://example.com/photo.jpg',
        bio: 'Just a test user',
        classYear: '2025',
        location: 'Warren Towers',
        interests: ['studying', 'music', 'sports'],
        gender: 'male',
        createdAt: _fixedDate,
        lastSeen: _fixedDate,
        isOnline: true,
        hasCreatedProfile: true,
        authProvider: 'google',
        isEmailVerified: true,
        subscribedTopics: ['general', 'events'],
        blockedUserIds: [],
        blockedByUserIds: [],
      );

  /// A second user for testing interactions
  static UserModel get secondUser => UserModel(
        id: 'user-456',
        email: 'seconduser@bu.edu',
        username: 'seconduser',
        displayName: 'Second User',
        gender: 'female',
        createdAt: _fixedDate,
        hasCreatedProfile: true,
        authProvider: 'apple',
        isEmailVerified: true,
      );

  /// A user who has blocked basicUser
  static UserModel get userWhoBlocked => UserModel(
        id: 'user-789',
        email: 'blocker@bu.edu',
        username: 'blocker',
        displayName: 'Blocker User',
        gender: 'male',
        createdAt: _fixedDate,
        hasCreatedProfile: true,
        blockedUserIds: ['user-123'], // Blocked basicUser
      );

  /// A user who is blocked by basicUser
  static UserModel get blockedUser => UserModel(
        id: 'user-blocked',
        email: 'blocked@bu.edu',
        username: 'blockeduser',
        displayName: 'Blocked User',
        gender: 'female',
        createdAt: _fixedDate,
        hasCreatedProfile: true,
        blockedByUserIds: ['user-123'], // Blocked by basicUser
      );

  /// A new user who hasn't completed profile setup
  static UserModel get incompleteProfileUser => UserModel(
        id: 'user-new',
        email: 'newuser@bu.edu',
        username: 'newuser',
        createdAt: _fixedDate,
        hasCreatedProfile: false,
        isEmailVerified: false,
      );

  /// An Apple sign-in user with verified BU email
  static UserModel get appleUser => UserModel(
        id: 'user-apple',
        email: 'private@privaterelay.appleid.com',
        username: 'appleuser',
        displayName: 'Apple User',
        gender: 'female',
        createdAt: _fixedDate,
        hasCreatedProfile: true,
        authProvider: 'apple',
        isEmailVerified: true,
        verifiedEmail: 'appleuser@bu.edu',
        appleUserId: 'apple-id-12345',
      );

  /// Creates a custom user with specified overrides
  static UserModel custom({
    String? id,
    String? email,
    String? username,
    String? displayName,
    String? gender,
    bool? hasCreatedProfile,
    bool? isEmailVerified,
    List<String>? blockedUserIds,
    List<String>? blockedByUserIds,
  }) {
    return basicUser.copyWith(
      id: id,
      email: email,
      username: username,
      displayName: displayName,
      gender: gender,
      hasCreatedProfile: hasCreatedProfile,
      isEmailVerified: isEmailVerified,
      blockedUserIds: blockedUserIds,
      blockedByUserIds: blockedByUserIds,
    );
  }

  /// List of multiple users for testing feeds/lists
  static List<UserModel> get multipleUsers => [
        basicUser,
        secondUser,
        userWhoBlocked,
      ];
}
