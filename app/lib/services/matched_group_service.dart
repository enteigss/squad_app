import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/matched_group_model.dart';
import '../models/user_model.dart';

class MatchedGroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get a stream of matched groups for a user
  Stream<List<MatchedGroupModel>> getMatchedGroupsForUser(String userId) {
    debugPrint('📋 Fetching matched groups for user: $userId');

    // Simple query to avoid needing composite index
    // Filter by status and sort in memory
    return _firestore
        .collection('matched_groups')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      debugPrint('📋 Found ${snapshot.docs.length} matched groups (before filter)');

      final groups = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return MatchedGroupModel.fromMap(data);
          })
          .where((group) => group.status == MatchedGroupStatus.active)
          .toList();

      // Sort by createdAt descending
      groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      debugPrint('📋 Returning ${groups.length} active matched groups');
      return groups;
    });
  }

  /// Get a single matched group by ID
  Future<MatchedGroupModel?> getMatchedGroup(String groupId) async {
    try {
      final doc =
          await _firestore.collection('matched_groups').doc(groupId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      data['id'] = doc.id;
      return MatchedGroupModel.fromMap(data);
    } catch (e) {
      debugPrint('❌ Error fetching matched group: $e');
      return null;
    }
  }

  /// Get user models for a list of member IDs
  Future<List<UserModel>> getGroupMembers(List<String> memberIds) async {
    final members = <UserModel>[];

    for (final id in memberIds) {
      try {
        final doc = await _firestore.collection('users').doc(id).get();
        if (doc.exists) {
          final data = doc.data()!;
          data['id'] = doc.id;
          members.add(UserModel.fromMap(data));
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching member $id: $e');
        // Continue loading other members
      }
    }

    return members;
  }

  /// Get members excluding the current user
  Future<List<UserModel>> getOtherGroupMembers(
    List<String> memberIds,
    String currentUserId,
  ) async {
    final otherMemberIds =
        memberIds.where((id) => id != currentUserId).toList();
    return getGroupMembers(otherMemberIds);
  }
}
