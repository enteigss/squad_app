import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_app/models/user_model.dart';
import 'package:squad_app/services/firestore_service.dart';

import '../../fixtures/user_fixtures.dart';
import '../../fixtures/post_fixtures.dart';

void main() {
  group('FirestoreService', () {
    late FirestoreService firestoreService;
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeFirestore);
    });

    // ──── SEED HELPERS ────

    Future<void> seedUser(UserModel user) async {
      await fakeFirestore
          .collection('users')
          .doc(user.id)
          .set(user.toMap());
    }

    Future<void> seedPost(String postId, List<String> participantIds) async {
      final post = PostFixtures.custom(
        id: postId,
        participantIds: participantIds,
      );
      await fakeFirestore
          .collection('posts')
          .doc(postId)
          .set(post.toMap());
    }

    // ──── updateUserProfile ────

    group('updateUserProfile', () {
      test('updates displayName for existing user', () async {
        // Arrange
        await seedUser(UserFixtures.basicUser);

        // Act
        await firestoreService.updateUserProfile(
          userId: 'user-123',
          displayName: 'New Name',
        );

        // Assert
        final doc =
            await fakeFirestore.collection('users').doc('user-123').get();
        expect(doc.data()?['displayName'], 'New Name');
        expect(doc.data()?['updatedAt'], isNotNull);
        // Merge preserves original fields
        expect(doc.data()?['email'], 'testuser@bu.edu');
        expect(doc.data()?['username'], 'testuser');
      });

      test('updates multiple fields simultaneously', () async {
        // Arrange
        await seedUser(UserFixtures.basicUser);

        // Act
        await firestoreService.updateUserProfile(
          userId: 'user-123',
          displayName: 'Updated',
          bio: 'New bio',
          age: 22,
          location: 'Boston',
          interests: ['coding'],
        );

        // Assert
        final doc =
            await fakeFirestore.collection('users').doc('user-123').get();
        expect(doc.data()?['displayName'], 'Updated');
        expect(doc.data()?['bio'], 'New bio');
        expect(doc.data()?['age'], 22);
        expect(doc.data()?['location'], 'Boston');
        expect(doc.data()?['interests'], ['coding']);
        expect(doc.data()?['updatedAt'], isNotNull);
        // Original field preserved
        expect(doc.data()?['email'], 'testuser@bu.edu');
      });

      test('only includes non-null fields in update', () async {
        // Arrange
        await seedUser(UserFixtures.basicUser);

        // Act
        await firestoreService.updateUserProfile(
          userId: 'user-123',
          bio: 'Only bio',
        );

        // Assert
        final doc =
            await fakeFirestore.collection('users').doc('user-123').get();
        expect(doc.data()?['bio'], 'Only bio');
        // displayName not wiped
        expect(doc.data()?['displayName'], 'Test User');
      });

      test('creates document if it does not exist (upsert)', () async {
        // Arrange - no seeding

        // Act
        await firestoreService.updateUserProfile(
          userId: 'new-user-id',
          displayName: 'Brand New',
        );

        // Assert
        final doc =
            await fakeFirestore.collection('users').doc('new-user-id').get();
        expect(doc.exists, true);
        expect(doc.data()?['displayName'], 'Brand New');
        expect(doc.data()?['updatedAt'], isNotNull);
      });

      test('always includes updatedAt timestamp', () async {
        // Arrange
        await seedUser(UserFixtures.basicUser);

        // Act - no optional fields
        await firestoreService.updateUserProfile(userId: 'user-123');

        // Assert
        final doc =
            await fakeFirestore.collection('users').doc('user-123').get();
        expect(doc.data()?['updatedAt'], isNotNull);
      });

      test('updates photoUrl field', () async {
        // Arrange
        await seedUser(UserFixtures.basicUser);

        // Act
        await firestoreService.updateUserProfile(
          userId: 'user-123',
          photoUrl: 'https://new.photo/img.jpg',
        );

        // Assert
        final doc =
            await fakeFirestore.collection('users').doc('user-123').get();
        expect(doc.data()?['photoUrl'], 'https://new.photo/img.jpg');
      });
    });

    // ──── searchUsers ────

    group('searchUsers', () {
      test('returns users matching prefix', () async {
        // Arrange
        await seedUser(UserFixtures.basicUser); // username: 'testuser'
        await seedUser(UserFixtures.secondUser); // username: 'seconduser'

        // Act
        final results = await firestoreService.searchUsers('test');

        // Assert
        expect(results, hasLength(1));
        expect(results.first.username, 'testuser');
      });

      test('returns empty list when no users match', () async {
        // Arrange
        await seedUser(UserFixtures.basicUser);

        // Act
        final results = await firestoreService.searchUsers('zzz');

        // Assert
        expect(results, isEmpty);
      });

      test('returns multiple matching users', () async {
        // Arrange
        await seedUser(
            UserFixtures.custom(id: 'u1', username: 'testuser'));
        await seedUser(
            UserFixtures.custom(id: 'u2', username: 'testadmin'));
        await seedUser(
            UserFixtures.custom(id: 'u3', username: 'testing123'));

        // Act
        final results = await firestoreService.searchUsers('test');

        // Assert
        expect(results, hasLength(3));
        for (final user in results) {
          expect(user.username, startsWith('test'));
        }
      });

      test('returns empty list when no users exist', () async {
        // Arrange - empty collection

        // Act
        final results = await firestoreService.searchUsers('any');

        // Assert
        expect(results, isEmpty);
      });

      test('limits results to 10 users', () async {
        // Arrange - seed 12 users
        for (int i = 0; i < 12; i++) {
          final padded = i.toString().padLeft(2, '0');
          await seedUser(UserFixtures.custom(
            id: 'user-$padded',
            username: 'user_$padded',
          ));
        }

        // Act
        final results = await firestoreService.searchUsers('user_');

        // Assert
        expect(results.length, lessThanOrEqualTo(10));
      });
    });

    // ──── getUser ────

    group('getUser', () {
      test('returns UserModel when user exists', () async {
        // Arrange
        await seedUser(UserFixtures.basicUser);

        // Act
        final result = await firestoreService.getUser('user-123');

        // Assert
        expect(result, isNotNull);
        expect(result!.id, 'user-123');
        expect(result.email, 'testuser@bu.edu');
        expect(result.username, 'testuser');
        expect(result.displayName, 'Test User');
      });

      test('returns null when user does not exist', () async {
        // Arrange - no seeding

        // Act
        final result = await firestoreService.getUser('nonexistent-id');

        // Assert
        expect(result, isNull);
      });

      test('returns user with all fields populated correctly', () async {
        // Arrange
        await seedUser(UserFixtures.basicUser);

        // Act
        final result = await firestoreService.getUser('user-123');

        // Assert
        expect(result, isNotNull);
        expect(result!.bio, 'Just a test user');
        expect(result.location, 'Warren Towers');
        expect(result.interests, containsAll(['studying', 'music', 'sports']));
        expect(result.classYear, '2025');
        expect(result.isOnline, true);
        expect(result.hasCreatedProfile, true);
        expect(result.authProvider, 'google');
        expect(result.isEmailVerified, true);
      });
    });

    // ──── removeMemberFromPost ────

    group('removeMemberFromPost', () {
      test('removes userId from participantIds array', () async {
        // Arrange
        await seedPost('post-123', ['user-123', 'user-456']);

        // Act
        await firestoreService.removeMemberFromPost('post-123', 'user-456');

        // Assert
        final doc =
            await fakeFirestore.collection('posts').doc('post-123').get();
        final participantIds =
            List<String>.from(doc.data()?['participantIds'] ?? []);
        expect(participantIds, contains('user-123'));
        expect(participantIds, isNot(contains('user-456')));
      });

      test('does not error when userId is not a participant', () async {
        // Arrange
        await seedPost('post-123', ['user-123']);

        // Act - should not throw
        await firestoreService.removeMemberFromPost('post-123', 'user-999');

        // Assert
        final doc =
            await fakeFirestore.collection('posts').doc('post-123').get();
        final participantIds =
            List<String>.from(doc.data()?['participantIds'] ?? []);
        expect(participantIds, ['user-123']);
      });

      test('throws exception when post does not exist', () async {
        // Arrange - no seeding

        // Act & Assert
        await expectLater(
          () => firestoreService.removeMemberFromPost(
              'nonexistent', 'user-123'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to remove member from post'),
            ),
          ),
        );
      });
    });
  });
}
