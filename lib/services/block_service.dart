import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/block_model.dart';
import '../models/user_model.dart';

class BlockService {
  static final BlockService _instance = BlockService._internal();
  factory BlockService() => _instance;
  BlockService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Block a user
  Future<void> blockUser(String targetUserId, {String? reason}) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      if (currentUserId == targetUserId) {
        throw Exception('Cannot block yourself');
      }

      // Check if already blocked
      if (await isBlocked(targetUserId)) {
        debugPrint('User $targetUserId is already blocked');
        return;
      }

      final blockId = '${currentUserId}_$targetUserId';
      final block = BlockModel(
        id: blockId,
        blockerId: currentUserId,
        blockedId: targetUserId,
        createdAt: DateTime.now(),
        reason: reason,
      );

      // Use a batch write to ensure consistency
      final batch = _firestore.batch();

      // Create block document
      batch.set(_firestore.collection('blocks').doc(blockId), block.toMap());

      // Update blocker's blockedUserIds
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'blockedUserIds': FieldValue.arrayUnion([targetUserId]),
      });

      // Update blocked user's blockedByUserIds
      batch.update(_firestore.collection('users').doc(targetUserId), {
        'blockedByUserIds': FieldValue.arrayUnion([currentUserId]),
      });

      await batch.commit();
      debugPrint('Successfully blocked user: $targetUserId');

      // Remove blocked user from hangouts hosted by current user
      await _removeFromHostedHangouts(currentUserId, targetUserId);
    } catch (e) {
      debugPrint('Error blocking user: $e');
      rethrow;
    }
  }

  /// Unblock a user
  Future<void> unblockUser(String targetUserId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Check if actually blocked
      if (!await isBlocked(targetUserId)) {
        debugPrint('User $targetUserId is not blocked');
        return;
      }

      final blockId = '${currentUserId}_$targetUserId';

      // Use a batch write to ensure consistency
      final batch = _firestore.batch();

      // Delete block document
      batch.delete(_firestore.collection('blocks').doc(blockId));

      // Update blocker's blockedUserIds
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'blockedUserIds': FieldValue.arrayRemove([targetUserId]),
      });

      // Update blocked user's blockedByUserIds
      batch.update(_firestore.collection('users').doc(targetUserId), {
        'blockedByUserIds': FieldValue.arrayRemove([currentUserId]),
      });

      await batch.commit();
      debugPrint('Successfully unblocked user: $targetUserId');
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      rethrow;
    }
  }

  /// Check if a user is blocked by current user
  Future<bool> isBlocked(String userId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return false;

      final blockId = '${currentUserId}_$userId';
      final doc = await _firestore.collection('blocks').doc(blockId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking if user is blocked: $e');
      return false;
    }
  }

  /// Check if current user is blocked by another user
  Future<bool> isBlockedBy(String userId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return false;

      final blockId = '${userId}_$currentUserId';
      final doc = await _firestore.collection('blocks').doc(blockId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking if blocked by user: $e');
      return false;
    }
  }

  /// Check if there's any blocking relationship between two users
  Future<bool> isBlockingRelationship(String userId) async {
    final blocked = await isBlocked(userId);
    final blockedBy = await isBlockedBy(userId);
    return blocked || blockedBy;
  }

  /// Get list of users blocked by current user
  Future<List<UserModel>> getBlockedUsers() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return [];

      // Get user's blocked list
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      final blockedIds = List<String>.from(
        userDoc.data()?['blockedUserIds'] ?? [],
      );

      if (blockedIds.isEmpty) return [];

      // Get user details for blocked users
      final List<UserModel> blockedUsers = [];
      for (String blockedId in blockedIds) {
        try {
          final blockedUserDoc = await _firestore
              .collection('users')
              .doc(blockedId)
              .get();
          if (blockedUserDoc.exists) {
            blockedUsers.add(UserModel.fromMap(blockedUserDoc.data()!));
          }
        } catch (e) {
          debugPrint('Error getting blocked user $blockedId: $e');
          // Continue with other users even if one fails
        }
      }

      return blockedUsers;
    } catch (e) {
      debugPrint('Error getting blocked users: $e');
      return [];
    }
  }

  /// Get list of block relationships for current user
  Stream<List<BlockModel>> getBlocksStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('blocks')
        .where('blockerId', isEqualTo: currentUserId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BlockModel.fromMap(doc.data()))
              .toList(),
        );
  }

  /// Helper method to filter out blocked users from a list
  List<UserModel> filterBlockedUsers(
    List<UserModel> users,
    List<String> blockedUserIds,
    List<String> blockedByUserIds,
  ) {
    return users.where((user) {
      return !blockedUserIds.contains(user.id) &&
          !blockedByUserIds.contains(user.id);
    }).toList();
  }

  /// Helper method to check if content should be filtered (from blocked user)
  /// Only filters if current user has blocked the author (asymmetric filtering)
  bool shouldFilterContent(
    String authorId,
    List<String> blockedUserIds,
    List<String> blockedByUserIds,
  ) {
    return blockedUserIds.contains(authorId);
  }

  /// Helper method to check if content should be censored (for messages)
  bool shouldCensorContent(
    String authorId,
    List<String> blockedUserIds,
    List<String> blockedByUserIds,
  ) {
    return blockedUserIds.contains(authorId);
  }

  /// Helper method to check if hangout should be hidden from current user because they are blocked by host
  bool shouldHideHangoutFromBlocked(
    String hangoutHostId,
    List<String> blockedUserIds,
    List<String> blockedByUserIds,
  ) {
    return blockedByUserIds.contains(hangoutHostId);
  }

  /// Check if user can access a hangout (not blocked by host)
  Future<bool> canAccessHangout(String hangoutHostId, String userId) async {
    try {
      final blockId = '${hangoutHostId}_$userId';
      final doc = await _firestore.collection('blocks').doc(blockId).get();
      return !doc.exists; // Can access if not blocked by host
    } catch (e) {
      debugPrint('Error checking hangout access: $e');
      return true; // Default to allowing access if check fails
    }
  }

  /// Remove blocked user from all hangouts hosted by the blocker
  Future<void> _removeFromHostedHangouts(
    String hostId,
    String blockedUserId,
  ) async {
    try {
      // Get all posts/hangouts hosted by the current user
      final postsQuery = await _firestore
          .collection('posts')
          .where('authorId', isEqualTo: hostId)
          .where('participantIds', arrayContains: blockedUserId)
          .get();

      if (postsQuery.docs.isEmpty) {
        debugPrint('No hangouts found where blocked user is participant');
        return;
      }

      // Use batch to remove blocked user from all hangouts
      final batch = _firestore.batch();

      for (final doc in postsQuery.docs) {
        batch.update(doc.reference, {
          'participantIds': FieldValue.arrayRemove([blockedUserId]),
        });
        debugPrint('Removing $blockedUserId from hangout: ${doc.id}');
      }

      await batch.commit();
      debugPrint(
        'Successfully removed blocked user from ${postsQuery.docs.length} hangouts',
      );
    } catch (e) {
      debugPrint('Error removing blocked user from hangouts: $e');
      // Don't rethrow to prevent blocking operation from failing
    }
  }
}
