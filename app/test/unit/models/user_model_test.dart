import 'package:flutter_test/flutter_test.dart';
import 'package:squad_app/models/user_model.dart';

void main() {
  group('UserModel', () {
    final fixedDate = DateTime(2024, 1, 1, 12, 0, 0);

    UserModel createTestUser({
      String id = 'user-123',
      String email = 'test@bu.edu',
      String username = 'testuser',
      String? displayName = 'Test User',
      String? gender = 'male',
      bool hasCreatedProfile = true,
      bool isEmailVerified = true,
      List<String> blockedUserIds = const [],
      List<String> blockedByUserIds = const [],
    }) {
      return UserModel(
        id: id,
        email: email,
        username: username,
        displayName: displayName,
        gender: gender,
        createdAt: fixedDate,
        hasCreatedProfile: hasCreatedProfile,
        isEmailVerified: isEmailVerified,
        blockedUserIds: blockedUserIds,
        blockedByUserIds: blockedByUserIds,
      );
    }

    group('fromMap', () {
      test('creates UserModel from valid map', () {
        final map = {
          'id': 'user-123',
          'email': 'test@bu.edu',
          'username': 'testuser',
          'displayName': 'Test User',
          'photoUrl': 'https://example.com/photo.jpg',
          'bio': 'Hello world',
          'classYear': '2025',
          'location': 'Warren Towers',
          'interests': ['music', 'sports'],
          'gender': 'male',
          'createdAt': fixedDate.millisecondsSinceEpoch,
          'lastSeen': fixedDate.millisecondsSinceEpoch,
          'isOnline': true,
          'hasCreatedProfile': true,
          'authProvider': 'google',
          'isEmailVerified': true,
          'blockedUserIds': ['blocked-1'],
          'blockedByUserIds': ['blocker-1'],
        };

        final user = UserModel.fromMap(map);

        expect(user.id, 'user-123');
        expect(user.email, 'test@bu.edu');
        expect(user.username, 'testuser');
        expect(user.displayName, 'Test User');
        expect(user.photoUrl, 'https://example.com/photo.jpg');
        expect(user.bio, 'Hello world');
        expect(user.classYear, '2025');
        expect(user.location, 'Warren Towers');
        expect(user.interests, ['music', 'sports']);
        expect(user.gender, 'male');
        expect(user.isOnline, true);
        expect(user.hasCreatedProfile, true);
        expect(user.authProvider, 'google');
        expect(user.isEmailVerified, true);
        expect(user.blockedUserIds, ['blocked-1']);
        expect(user.blockedByUserIds, ['blocker-1']);
      });

      test('handles missing optional fields with defaults', () {
        final map = {
          'id': 'user-123',
          'email': 'test@bu.edu',
          'username': 'testuser',
          'createdAt': fixedDate.millisecondsSinceEpoch,
        };

        final user = UserModel.fromMap(map);

        expect(user.displayName, isNull);
        expect(user.photoUrl, isNull);
        expect(user.bio, isNull);
        expect(user.gender, isNull);
        expect(user.interests, isEmpty);
        expect(user.isOnline, false);
        expect(user.hasCreatedProfile, false);
        expect(user.blockedUserIds, isEmpty);
        expect(user.blockedByUserIds, isEmpty);
      });

      test('handles empty strings in required fields', () {
        final map = <String, dynamic>{
          'id': '',
          'email': '',
          'username': '',
          'createdAt': fixedDate.millisecondsSinceEpoch,
        };

        final user = UserModel.fromMap(map);

        expect(user.id, '');
        expect(user.email, '');
        expect(user.username, '');
      });

      test('handles null map values with defaults', () {
        final map = <String, dynamic>{
          'id': null,
          'email': null,
          'username': null,
          'interests': null,
          'blockedUserIds': null,
          'createdAt': fixedDate.millisecondsSinceEpoch,
        };

        final user = UserModel.fromMap(map);

        expect(user.id, '');
        expect(user.email, '');
        expect(user.username, '');
        expect(user.interests, isEmpty);
        expect(user.blockedUserIds, isEmpty);
      });
    });

    group('toMap', () {
      test('converts UserModel to map correctly', () {
        final user = UserModel(
          id: 'user-123',
          email: 'test@bu.edu',
          username: 'testuser',
          displayName: 'Test User',
          photoUrl: 'https://example.com/photo.jpg',
          bio: 'Hello',
          classYear: '2025',
          location: 'Warren',
          interests: ['music'],
          gender: 'male',
          createdAt: fixedDate,
          lastSeen: fixedDate,
          isOnline: true,
          hasCreatedProfile: true,
          authProvider: 'google',
          isEmailVerified: true,
          blockedUserIds: ['blocked-1'],
          blockedByUserIds: ['blocker-1'],
        );

        final map = user.toMap();

        expect(map['id'], 'user-123');
        expect(map['email'], 'test@bu.edu');
        expect(map['username'], 'testuser');
        expect(map['displayName'], 'Test User');
        expect(map['photoUrl'], 'https://example.com/photo.jpg');
        expect(map['bio'], 'Hello');
        expect(map['classYear'], '2025');
        expect(map['location'], 'Warren');
        expect(map['interests'], ['music']);
        expect(map['gender'], 'male');
        expect(map['createdAt'], fixedDate.millisecondsSinceEpoch);
        expect(map['lastSeen'], fixedDate.millisecondsSinceEpoch);
        expect(map['isOnline'], true);
        expect(map['hasCreatedProfile'], true);
        expect(map['authProvider'], 'google');
        expect(map['isEmailVerified'], true);
        expect(map['blockedUserIds'], ['blocked-1']);
        expect(map['blockedByUserIds'], ['blocker-1']);
      });

      test('handles null optional fields', () {
        final user = UserModel(
          id: 'user-123',
          email: 'test@bu.edu',
          username: 'testuser',
          createdAt: fixedDate,
        );

        final map = user.toMap();

        expect(map['displayName'], isNull);
        expect(map['photoUrl'], isNull);
        expect(map['bio'], isNull);
        expect(map['lastSeen'], isNull);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = createTestUser();
        final copy = original.copyWith(
          displayName: 'New Name',
          bio: 'New Bio',
          isOnline: true,
        );

        expect(copy.displayName, 'New Name');
        expect(copy.bio, 'New Bio');
        expect(copy.isOnline, true);
        // Original fields unchanged
        expect(copy.id, original.id);
        expect(copy.email, original.email);
        expect(copy.username, original.username);
      });

      test('returns copy with same values when no arguments provided', () {
        final original = createTestUser();
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.email, original.email);
        expect(copy.username, original.username);
        expect(copy.displayName, original.displayName);
        expect(copy.gender, original.gender);
      });

      test('can update blocked user lists', () {
        final original = createTestUser();
        final copy = original.copyWith(
          blockedUserIds: ['new-blocked-user'],
          blockedByUserIds: ['new-blocker'],
        );

        expect(copy.blockedUserIds, ['new-blocked-user']);
        expect(copy.blockedByUserIds, ['new-blocker']);
      });
    });

    group('roundtrip serialization', () {
      test('toMap then fromMap produces equivalent object', () {
        final original = UserModel(
          id: 'user-123',
          email: 'test@bu.edu',
          username: 'testuser',
          displayName: 'Test User',
          photoUrl: 'https://example.com/photo.jpg',
          bio: 'Hello world',
          classYear: '2025',
          location: 'Warren Towers',
          interests: ['music', 'sports'],
          gender: 'male',
          createdAt: fixedDate,
          lastSeen: fixedDate,
          isOnline: true,
          hasCreatedProfile: true,
          authProvider: 'google',
          isEmailVerified: true,
          blockedUserIds: ['blocked-1'],
          blockedByUserIds: ['blocker-1'],
          genderChangeCount: 1,
          genderChangedAt: fixedDate,
        );

        final map = original.toMap();
        final restored = UserModel.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.email, original.email);
        expect(restored.username, original.username);
        expect(restored.displayName, original.displayName);
        expect(restored.photoUrl, original.photoUrl);
        expect(restored.bio, original.bio);
        expect(restored.classYear, original.classYear);
        expect(restored.interests, original.interests);
        expect(restored.gender, original.gender);
        expect(restored.hasCreatedProfile, original.hasCreatedProfile);
        expect(restored.blockedUserIds, original.blockedUserIds);
        expect(restored.blockedByUserIds, original.blockedByUserIds);
        expect(restored.genderChangeCount, original.genderChangeCount);
      });
    });

    group('edge cases', () {
      test('handles Apple auth user with private relay email', () {
        final user = UserModel(
          id: 'user-apple',
          email: 'private@privaterelay.appleid.com',
          username: 'appleuser',
          createdAt: fixedDate,
          authProvider: 'apple',
          verifiedEmail: 'real@bu.edu',
          appleUserId: 'apple-id-12345',
        );

        expect(user.authProvider, 'apple');
        expect(user.verifiedEmail, 'real@bu.edu');
        expect(user.appleUserId, 'apple-id-12345');
      });

      test('handles hangout chat notifications map', () {
        final user = UserModel(
          id: 'user-123',
          email: 'test@bu.edu',
          username: 'testuser',
          createdAt: fixedDate,
          hangoutChatNotifications: {
            'hangout-1': true,
            'hangout-2': false,
          },
        );

        expect(user.hangoutChatNotifications['hangout-1'], true);
        expect(user.hangoutChatNotifications['hangout-2'], false);
      });
    });
  });
}
