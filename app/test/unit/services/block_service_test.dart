import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_app/models/block_model.dart';
import 'package:squad_app/services/block_service.dart';

import '../../fixtures/user_fixtures.dart';
import '../../fixtures/post_fixtures.dart';

void main() {
  group('BlockService', () {
    late BlockService blockService;
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;

    // IDs we'll reuse across tests
    const currentUserId = 'user-123';
    const targetUserId = 'user-456';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: currentUserId, isAnonymous: false),
      );
      blockService = BlockService(firestore: fakeFirestore, auth: mockAuth);
    });

    /// Helper to seed both users into Firestore
    Future<void> seedBothUsers() async {
      await fakeFirestore
          .collection('users')
          .doc(currentUserId)
          .set(UserFixtures.basicUser.toMap());
      await fakeFirestore
          .collection('users')
          .doc(targetUserId)
          .set(UserFixtures.secondUser.toMap());
    }

    /// Helper to create an existing block relationship
    Future<void> seedBlock() async {
      await seedBothUsers();
      final block = BlockModel(
        id: '${currentUserId}_$targetUserId',
        blockerId: currentUserId,
        blockedId: targetUserId,
        createdAt: DateTime.now(),
      );
      await fakeFirestore
          .collection('blocks')
          .doc(block.id)
          .set(block.toMap());
      await fakeFirestore.collection('users').doc(currentUserId).update({
        'blockedUserIds': [targetUserId],
      });
      await fakeFirestore.collection('users').doc(targetUserId).update({
        'blockedByUserIds': [currentUserId],
      });
    }

    group('blockUser', () {
      test('creates block document and updates both users', () async {
        // Arrange
        await seedBothUsers();

        // Act
        await blockService.blockUser(targetUserId);

        // Assert
        final blockDoc = await fakeFirestore
            .collection('blocks')
            .doc('${currentUserId}_$targetUserId')
            .get();
        expect(blockDoc.exists, true);
        expect(blockDoc.data()?['blockerId'], currentUserId);
        expect(blockDoc.data()?['blockedId'], targetUserId);

        final currentUserDoc = await fakeFirestore
            .collection('users')
            .doc(currentUserId)
            .get();
        expect(
          currentUserDoc.data()?['blockedUserIds'],
          contains(targetUserId),
        );

        final targetUserDoc = await fakeFirestore
            .collection('users')
            .doc(targetUserId)
            .get();
        expect(
          targetUserDoc.data()?['blockedByUserIds'],
          contains(currentUserId),
        );
      });

      test('removes blocked user from hangouts hosted by blocker', () async {
        // Arrange
        await seedBothUsers();
        final plan = PostFixtures.ongoingPost;
        await fakeFirestore
            .collection('posts')
            .doc('post-456')
            .set(plan.toMap());

        // Act
        await blockService.blockUser(targetUserId);

        // Assert
        final postDoc = await fakeFirestore
            .collection('posts')
            .doc('post-456')
            .get();
        expect(
          postDoc.data()?['participantIds'],
          isNot(contains(targetUserId)),
        );
      });

      test('stores reason when provided', () async {
        // Arrange
        await seedBothUsers();

        // Act
        await blockService.blockUser(targetUserId, reason: 'harassment');

        // Assert
        final blockDoc = await fakeFirestore
            .collection('blocks')
            .doc('${currentUserId}_$targetUserId')
            .get();
        expect(blockDoc.data()?['reason'], 'harassment');
      });

      test('throws when user is not authenticated', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(signedIn: false);
        blockService = BlockService(firestore: fakeFirestore, auth: mockAuth);

        // Act & Assert
        await expectLater(
          () => blockService.blockUser(targetUserId),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('User not authenticated'),
            ),
          ),
        );
      });

      test('throws when trying to block yourself', () async {
        // Act & Assert
        await expectLater(
          () => blockService.blockUser(currentUserId),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Cannot block yourself'),
            ),
          ),
        );
      });

      test('silently returns when user is already blocked', () async {
        // Arrange — create an existing block
        await seedBlock();

        // Act — block again
        await blockService.blockUser(targetUserId);

        // Assert — should still only have one block document
        final blocks = await fakeFirestore.collection('blocks').get();
        expect(blocks.docs.length, 1);
      });
    });

    group('unblockUser', () {
      test('removes block document and updates both users', () async {
        // Arrange
        await seedBlock();

        // Act
        await blockService.unblockUser(targetUserId);

        // Assert
        final blockDoc = await fakeFirestore
            .collection('blocks')
            .doc('${currentUserId}_$targetUserId')
            .get();
        expect(blockDoc.exists, false);

        final currentUserDoc = await fakeFirestore
            .collection('users')
            .doc(currentUserId)
            .get();
        expect(
          currentUserDoc.data()?['blockedUserIds'],
          isNot(contains(targetUserId)),
        );

        final targetUserDoc = await fakeFirestore
            .collection('users')
            .doc(targetUserId)
            .get();
        expect(
          targetUserDoc.data()?['blockedByUserIds'],
          isNot(contains(currentUserId)),
        );
      });

      test('throws when user is not authenticated', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(signedIn: false);
        blockService = BlockService(firestore: fakeFirestore, auth: mockAuth);

        // Act & Assert
        await expectLater(
          () => blockService.unblockUser(targetUserId),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('User not authenticated'),
            ),
          ),
        );
      });

      test('silently returns when user is not blocked', () async {
        // Arrange — no block exists
        await seedBothUsers();

        // Act & Assert — should not throw
        await blockService.unblockUser(targetUserId);

        // Verify no block documents were created
        final blocks = await fakeFirestore.collection('blocks').get();
        expect(blocks.docs.length, 0);
      });
    });

    group('isBlocked', () {
      test('returns true when user is blocked', () async {
        // Arrange
        await seedBlock();

        // Act & Assert
        expect(await blockService.isBlocked(targetUserId), true);
      });

      test('returns false when user is not blocked', () async {
        // Act & Assert
        expect(await blockService.isBlocked(targetUserId), false);
      });

      test('returns false when not authenticated', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(signedIn: false);
        blockService = BlockService(firestore: fakeFirestore, auth: mockAuth);

        // Act & Assert
        expect(await blockService.isBlocked(targetUserId), false);
      });
    });

    group('isBlockedBy', () {
      test('returns true when blocked by user', () async {
        // Arrange — create a reverse block (target blocked current user)
        final block = BlockModel(
          id: '${targetUserId}_$currentUserId',
          blockerId: targetUserId,
          blockedId: currentUserId,
          createdAt: DateTime.now(),
        );
        await fakeFirestore
            .collection('blocks')
            .doc(block.id)
            .set(block.toMap());

        // Act & Assert
        expect(await blockService.isBlockedBy(targetUserId), true);
      });

      test('returns false when not blocked by user', () async {
        // Act & Assert
        expect(await blockService.isBlockedBy(targetUserId), false);
      });
    });

    group('isBlockingRelationship', () {
      test('returns true when current user blocked target', () async {
        // Arrange
        await seedBlock();

        // Act & Assert
        expect(await blockService.isBlockingRelationship(targetUserId), true);
      });

      test('returns true when target blocked current user', () async {
        // Arrange — reverse block
        final block = BlockModel(
          id: '${targetUserId}_$currentUserId',
          blockerId: targetUserId,
          blockedId: currentUserId,
          createdAt: DateTime.now(),
        );
        await fakeFirestore
            .collection('blocks')
            .doc(block.id)
            .set(block.toMap());

        // Act & Assert
        expect(await blockService.isBlockingRelationship(targetUserId), true);
      });

      test('returns false when no blocking relationship', () async {
        // Act & Assert
        expect(await blockService.isBlockingRelationship(targetUserId), false);
      });
    });

    group('getBlockedUsers', () {
      test('returns list of blocked users', () async {
        // Arrange
        await seedBlock();

        // Act
        final blockedUsers = await blockService.getBlockedUsers();

        // Assert
        expect(blockedUsers.length, 1);
        expect(blockedUsers.first.id, targetUserId);
        expect(blockedUsers.first.email, 'seconduser@bu.edu');
      });

      test('returns empty list when no users are blocked', () async {
        // Arrange
        await seedBothUsers();

        // Act
        final blockedUsers = await blockService.getBlockedUsers();

        // Assert
        expect(blockedUsers, isEmpty);
      });

      test('returns empty list when not authenticated', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(signedIn: false);
        blockService = BlockService(firestore: fakeFirestore, auth: mockAuth);

        // Act
        final blockedUsers = await blockService.getBlockedUsers();

        // Assert
        expect(blockedUsers, isEmpty);
      });
    });

    group('getBlocksStream', () {
      test('emits block models for current user', () async {
        // Arrange
        await seedBlock();

        // Act & Assert
        final stream = blockService.getBlocksStream();
        final blocks = await stream.first;
        expect(blocks.length, 1);
        expect(blocks.first.blockerId, currentUserId);
        expect(blocks.first.blockedId, targetUserId);
      });

      test('emits empty list when not authenticated', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(signedIn: false);
        blockService = BlockService(firestore: fakeFirestore, auth: mockAuth);

        // Act & Assert
        final stream = blockService.getBlocksStream();
        final blocks = await stream.first;
        expect(blocks, isEmpty);
      });
    });

    group('filterBlockedUsers', () {
      test('filters out users blocked by current user', () async {
        // Arrange
        final users = UserFixtures.multipleUsers;
        final blockedUserIds = [UserFixtures.secondUser.id];

        // Act
        final filtered = blockService.filterBlockedUsers(
          users,
          blockedUserIds,
          [],
        );

        // Assert
        expect(filtered.length, 2);
        expect(filtered.any((u) => u.id == targetUserId), false);
      });

      test('filters out users who blocked current user', () async {
        // Arrange
        final users = UserFixtures.multipleUsers;
        final blockedByUserIds = [UserFixtures.userWhoBlocked.id];

        // Act
        final filtered = blockService.filterBlockedUsers(
          users,
          [],
          blockedByUserIds,
        );

        // Assert
        expect(filtered.any((u) => u.id == 'user-789'), false);
      });

      test('returns all users when no blocks exist', () async {
        // Arrange
        final users = UserFixtures.multipleUsers;

        // Act
        final filtered = blockService.filterBlockedUsers(users, [], []);

        // Assert
        expect(filtered.length, users.length);
      });
    });

    group('shouldFilterContent', () {
      test('returns true when author is blocked by current user', () {
        expect(
          blockService.shouldFilterContent(targetUserId, [targetUserId], []),
          true,
        );
      });

      test('returns false when author is not blocked', () {
        expect(
          blockService.shouldFilterContent(targetUserId, [], []),
          false,
        );
      });

      test('returns false when author blocked current user (asymmetric)', () {
        // Current user is blocked BY the author, but hasn't blocked them
        expect(
          blockService.shouldFilterContent(targetUserId, [], [targetUserId]),
          false,
        );
      });
    });

    group('shouldCensorContent', () {
      test('returns true when author is blocked', () {
        expect(
          blockService.shouldCensorContent(targetUserId, [targetUserId], []),
          true,
        );
      });

      test('returns false when author is not blocked', () {
        expect(
          blockService.shouldCensorContent(targetUserId, [], []),
          false,
        );
      });
    });

    group('shouldHideHangoutFromBlocked', () {
      test('returns true when blocked by host', () {
        expect(
          blockService.shouldHideHangoutFromBlocked(
            targetUserId,
            [],
            [targetUserId],
          ),
          true,
        );
      });

      test('returns false when not blocked by host', () {
        expect(
          blockService.shouldHideHangoutFromBlocked(targetUserId, [], []),
          false,
        );
      });
    });

    group('canAccessHangout', () {
      test('returns true when not blocked by host', () async {
        // No block document exists
        expect(
          await blockService.canAccessHangout(targetUserId, currentUserId),
          true,
        );
      });

      test('returns false when blocked by host', () async {
        // Arrange — host blocked the user
        final block = BlockModel(
          id: '${targetUserId}_$currentUserId',
          blockerId: targetUserId,
          blockedId: currentUserId,
          createdAt: DateTime.now(),
        );
        await fakeFirestore
            .collection('blocks')
            .doc(block.id)
            .set(block.toMap());

        // Act & Assert
        expect(
          await blockService.canAccessHangout(targetUserId, currentUserId),
          false,
        );
      });
    });
  });
}
