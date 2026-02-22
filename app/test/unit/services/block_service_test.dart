import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
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

    group('blockUser', () {
      test('creates block document and updates both users', () async {
        // ========== ARRANGE ==========
        // Put both users into our fake Firestore so blockUser() can update them
        final currentUser = UserFixtures.basicUser;
        final targetUser = UserFixtures.secondUser;

        await fakeFirestore
            .collection('users')
            .doc(currentUserId)
            .set(currentUser.toMap());

        await fakeFirestore
            .collection('users')
            .doc(targetUserId)
            .set(targetUser.toMap());

        // ========== ACT ==========
        // Call the method we're testing
        await blockService.blockUser(targetUserId);

        // ========== ASSERT ==========
        // 1. A block document should exist with the correct ID format
        final blockDoc = await fakeFirestore
            .collection('blocks')
            .doc('${currentUserId}_$targetUserId')
            .get();
        expect(blockDoc.exists, true);
        expect(blockDoc.data()?['blockerId'], currentUserId);
        expect(blockDoc.data()?['blockedId'], targetUserId);

        // 2. Current user's blockedUserIds should contain the target
        final currentUserDoc = await fakeFirestore
            .collection('users')
            .doc(currentUserId)
            .get();
        expect(
          currentUserDoc.data()?['blockedUserIds'],
          contains(targetUserId),
        );

        // 3. Target user's blockedByUserIds should contain the current user
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
        // Put both users into our fake Firestore so blockUser() can update them
        final currentUser = UserFixtures.basicUser;
        final targetUser = UserFixtures.secondUser;
        final plan = PostFixtures.ongoingPost;

        await fakeFirestore
            .collection('users')
            .doc(currentUserId)
            .set(currentUser.toMap());

        await fakeFirestore
            .collection('users')
            .doc(targetUserId)
            .set(targetUser.toMap());

        // Add plan to firestore
        await fakeFirestore
            .collection('posts')
            .doc('post-456')
            .set(plan.toMap());

        await blockService.blockUser(targetUserId);

        // Check that the target user is no longer in the plan
        final postDoc = await fakeFirestore
            .collection('posts')
            .doc('post-456')
            .get();
        expect(
          postDoc.data()?['participantIds'],
          isNot(contains(targetUserId)),
        );
      });
    });
  });
}
