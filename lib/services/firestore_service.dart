import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../models/message_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<UserModel>> getGroupMembers(String currentUserId) async {
    try {
      // Get user document from firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();

      // Get user's group ID
      final groupId = userDoc.data()?['groupId'];
      if (groupId == null) return [];

      // Get group document from firestore
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();

      // Get group's members' IDs
      final memberIds = List<String>.from(groupDoc.data()?['memberIds'] ?? []);

      // Convert each memberId into a UserModel and add to list
      final List<UserModel> members = [];
      for (String memberId in memberIds) {
        // Remove literal quotes if they exist and trim whitespace
        final cleanMemberId = memberId
            .replaceAll('"', '')
            .replaceAll("'", '')
            .trim();

        final memberDoc = await _firestore
            .collection('users')
            .doc(cleanMemberId)
            .get();

        if (memberDoc.exists) {
          members.add(UserModel.fromMap(memberDoc.data()!));
        }
      }

      return members;
    } catch (e) {
      throw Exception('Failed to get group members: $e');
    }
  }

  Stream<List<GroupModel>> getUserGroups(String userId) {
    return _firestore
        .collection('groups')
        .where('memberIds', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GroupModel.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<void> updateUserProfile({
    required String userId,
    required String displayName,
    String? photoUrl,
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'displayName': displayName,
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<GroupModel> createGroup({
    required String name,
    required String createdBy,
    String? description,
    String? imageUrl,
    List<String> memberIds = const [],
    bool isPrivate = false,
  }) async {
    try {
      final String groupId = _firestore.collection('groups').doc().id;

      final GroupModel group = GroupModel(
        id: groupId,
        name: name,
        description: description,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        memberIds: [createdBy, ...memberIds],
        adminIds: [createdBy],
      );

      await _firestore.collection('groups').doc(groupId).set(group.toMap());

      await _updateUserGroupId(createdBy, groupId);
      for (String memberId in memberIds) {
        await _updateUserGroupId(memberId, groupId);
      }

      return group;
    } catch (e) {
      throw e;
    }
  }

  Future<void> addUserToGroup(String groupId, String userId) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
      });

      await _updateUserGroupId(userId, groupId);
    } catch (e) {
      throw e;
    }
  }

  Future<void> removeUserFromGroup(String groupId, String userId) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
        'adminIds': FieldValue.arrayRemove([userId]),
      });

      await _updateUserGroupId(userId, null);
    } catch (e) {
      throw e;
    }
  }

  Stream<List<MessageModel>> getGroupMessages(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<MessageModel> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String content,
    MessageType type = MessageType.text,
    String? senderAvatar,
    String? imageUrl,
    String? fileName,
    int? fileSize,
    String? replyToMessageId,
  }) async {
    try {
      final String messageId = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc()
          .id;

      final MessageModel message = MessageModel(
        id: messageId,
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        content: content,
        type: type,
        timestamp: DateTime.now(),
        readBy: [senderId],
        imageUrl: imageUrl,
        fileName: fileName,
        fileSize: fileSize,
        replyToMessageId: replyToMessageId,
      );

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());

      await _firestore.collection('groups').doc(groupId).update({
        'lastMessageId': messageId,
        'lastMessageTime': message.timestamp.millisecondsSinceEpoch,
      });

      return message;
    } catch (e) {
      throw e;
    }
  }

  Future<void> markMessageAsRead(
    String groupId,
    String messageId,
    String userId,
  ) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .update({
            'readBy': FieldValue.arrayUnion([userId]),
          });
    } catch (e) {
      throw e;
    }
  }

  Future<void> editMessage(
    String groupId,
    String messageId,
    String newContent,
  ) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .update({
            'content': newContent,
            'isEdited': true,
            'editedAt': DateTime.now().millisecondsSinceEpoch,
          });
    } catch (e) {
      throw e;
    }
  }

  Future<void> deleteMessage(String groupId, String messageId) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      throw e;
    }
  }

  Future<GroupModel?> getGroup(String groupId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('groups')
          .doc(groupId)
          .get();

      if (doc.exists) {
        return GroupModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw e;
    }
  }

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final QuerySnapshot result = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: query + 'z')
          .limit(10)
          .get();

      return result.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw e;
    }
  }

  Future<void> _updateUserGroupId(String userId, String? groupId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'groupId': groupId,
      });
    } catch (e) {
      throw e;
    }
  }
}
