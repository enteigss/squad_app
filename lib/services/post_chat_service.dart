import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_chat_message.dart';
import '../models/post_model.dart';

class PostChatService {
  static final PostChatService _instance = PostChatService._internal();
  factory PostChatService() => _instance;
  PostChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get real-time stream of messages for a post's chat
  Stream<List<PostChatMessage>> getChatMessages(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PostChatMessage.fromMap(doc.data()))
          .toList();
    });
  }

  // Send a text message to the post chat
  Future<PostChatMessage> sendMessage({
    required String postId,
    required String senderId,
    required String senderName,
    required String content,
    String? senderPhotoUrl,
    PostChatMessageType type = PostChatMessageType.text,
    String? imageUrl,
  }) async {
    try {
      final String messageId = _firestore
          .collection('posts')
          .doc(postId)
          .collection('chat')
          .doc()
          .id;

      final PostChatMessage message = PostChatMessage(
        id: messageId,
        postId: postId,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        content: content,
        type: type,
        timestamp: DateTime.now(),
        readBy: [senderId], // Sender has already "read" their own message
        imageUrl: imageUrl,
      );

      // Save the message
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('chat')
          .doc(messageId)
          .set(message.toMap());

      // Update post's last chat activity
      await _updatePostChatActivity(postId, messageId);

      return message;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Send system message (user joined, left, etc.)
  Future<PostChatMessage> sendSystemMessage({
    required String postId,
    required String content,
  }) async {
    try {
      final String messageId = _firestore
          .collection('posts')
          .doc(postId)
          .collection('chat')
          .doc()
          .id;

      final PostChatMessage message = PostChatMessage.createSystemMessage(
        postId: postId,
        content: content,
        messageId: messageId,
      );

      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('chat')
          .doc(messageId)
          .set(message.toMap());

      await _updatePostChatActivity(postId, messageId);

      return message;
    } catch (e) {
      throw Exception('Failed to send system message: $e');
    }
  }

  // Mark messages as read by a user
  Future<void> markMessagesAsRead(String postId, String userId) async {
    try {
      // Get unread messages for this user
      final unreadMessages = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('chat')
          .where('readBy', whereNotIn: [userId])
          .get();

      // Batch update to mark messages as read
      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        final readBy = List<String>.from(doc.data()['readBy'] ?? []);
        if (!readBy.contains(userId)) {
          readBy.add(userId);
          batch.update(doc.reference, {'readBy': readBy});
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to mark messages as read: $e');
    }
  }

  // Get unread message count for a user in a specific post
  Future<int> getUnreadCount(String postId, String userId) async {
    try {
      final unreadMessages = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('chat')
          .where('readBy', whereNotIn: [userId])
          .where('senderId', isNotEqualTo: userId) // Don't count own messages
          .get();

      return unreadMessages.docs.length;
    } catch (e) {
      return 0; // Return 0 on error rather than throwing
    }
  }

  // Edit a message (only by sender)
  Future<void> editMessage({
    required String postId,
    required String messageId,
    required String newContent,
    required String userId,
  }) async {
    try {
      final messageDoc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('chat')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final message = PostChatMessage.fromMap(messageDoc.data()!);
      if (message.senderId != userId) {
        throw Exception('You can only edit your own messages');
      }

      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('chat')
          .doc(messageId)
          .update({
        'content': newContent,
        'isEdited': true,
        'editedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to edit message: $e');
    }
  }

  // Delete a message (only by sender)
  Future<void> deleteMessage({
    required String postId,
    required String messageId,
    required String userId,
  }) async {
    try {
      final messageDoc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('chat')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final message = PostChatMessage.fromMap(messageDoc.data()!);
      if (message.senderId != userId) {
        throw Exception('You can only delete your own messages');
      }

      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('chat')
          .doc(messageId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  // Initialize chat when first user joins a post
  Future<void> initializeChat(String postId) async {
    try {
      // Check if chat already has messages
      final existingMessages = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('chat')
          .limit(1)
          .get();

      if (existingMessages.docs.isEmpty) {
        // Send welcome system message
        await sendSystemMessage(
          postId: postId,
          content: 'Welcome to the group chat! Use this space to coordinate your plans.',
        );
      }
    } catch (e) {
      // Don't throw error if chat initialization fails
      // Chat can still work without the welcome message
      print('Failed to initialize chat: $e');
    }
  }

  // Handle user joining post (send system message)
  Future<void> handleUserJoined({
    required String postId,
    required String userName,
  }) async {
    try {
      await sendSystemMessage(
        postId: postId,
        content: '$userName joined the group',
      );
    } catch (e) {
      print('Failed to send user joined message: $e');
    }
  }

  // Handle user leaving post (send system message)
  Future<void> handleUserLeft({
    required String postId,
    required String userName,
  }) async {
    try {
      await sendSystemMessage(
        postId: postId,
        content: '$userName left the group',
      );
    } catch (e) {
      print('Failed to send user left message: $e');
    }
  }

  // Archive chat when post is completed (make it read-only)
  Future<void> archiveChat(String postId) async {
    try {
      await sendSystemMessage(
        postId: postId,
        content: 'This event has ended. Chat is now read-only.',
      );
    } catch (e) {
      print('Failed to archive chat: $e');
    }
  }

  // Clean up old chats (call periodically)
  Future<void> cleanupOldChats() async {
    try {
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      // Get completed posts older than one week
      final oldPosts = await _firestore
          .collection('posts')
          .where('status', isEqualTo: PostStatus.completed.name)
          .where('lastChatActivity', isLessThan: Timestamp.fromDate(oneWeekAgo))
          .get();

      final batch = _firestore.batch();
      for (final postDoc in oldPosts.docs) {
        // Delete chat subcollection by deleting all messages
        final chatMessages = await _firestore
            .collection('posts')
            .doc(postDoc.id)
            .collection('chat')
            .get();

        for (final messageDoc in chatMessages.docs) {
          batch.delete(messageDoc.reference);
        }
      }

      await batch.commit();
    } catch (e) {
      print('Failed to cleanup old chats: $e');
    }
  }

  // Private helper to update post's last chat activity
  Future<void> _updatePostChatActivity(String postId, String messageId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'lastChatMessageId': messageId,
        'lastChatActivity': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      // Don't throw error if this fails, as the message was still sent
      print('Failed to update post chat activity: $e');
    }
  }

  // Check if user has permission to access this chat
  Future<bool> canAccessChat(String postId, String userId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return false;

      final post = Post.fromMap(postDoc.data()!);
      return post.participantIds.contains(userId);
    } catch (e) {
      return false;
    }
  }

  // Check if chat is read-only (post is completed)
  Future<bool> isChatReadOnly(String postId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return true;

      final post = Post.fromMap(postDoc.data()!);
      return post.status == PostStatus.completed;
    } catch (e) {
      return true; // Default to read-only on error
    }
  }
}