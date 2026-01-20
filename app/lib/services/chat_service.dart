import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import '../models/post_model.dart';
import '../models/matched_group_model.dart';

/// Generic chat service that works with both hangout posts and matched groups
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get the Firestore collection reference for a chat room's messages
  CollectionReference<Map<String, dynamic>> _chatCollection(
    ChatContext context,
    String chatRoomId,
  ) {
    switch (context) {
      case ChatContext.hangout:
        return _firestore
            .collection('posts')
            .doc(chatRoomId)
            .collection('chat');
      case ChatContext.matchedGroup:
        return _firestore
            .collection('matched_groups')
            .doc(chatRoomId)
            .collection('messages');
    }
  }

  /// Get the parent document reference (post or matched group)
  DocumentReference<Map<String, dynamic>> _parentDocument(
    ChatContext context,
    String chatRoomId,
  ) {
    switch (context) {
      case ChatContext.hangout:
        return _firestore.collection('posts').doc(chatRoomId);
      case ChatContext.matchedGroup:
        return _firestore.collection('matched_groups').doc(chatRoomId);
    }
  }

  /// Get real-time stream of messages for a chat room
  Stream<List<ChatMessage>> getMessages(ChatContext context, String chatRoomId) {
    return _chatCollection(context, chatRoomId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data(), context: context))
          .toList();
    });
  }

  /// Send a message to a chat room
  Future<ChatMessage> sendMessage({
    required ChatContext context,
    required String chatRoomId,
    required String senderId,
    required String senderName,
    required String content,
    String? senderPhotoUrl,
    ChatMessageType type = ChatMessageType.text,
    String? imageUrl,
    String? replyToMessageId,
  }) async {
    try {
      final collection = _chatCollection(context, chatRoomId);
      final String messageId = collection.doc().id;

      final ChatMessage message = ChatMessage(
        id: messageId,
        chatRoomId: chatRoomId,
        context: context,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        content: content,
        type: type,
        timestamp: DateTime.now(),
        readBy: [senderId], // Sender has already "read" their own message
        imageUrl: imageUrl,
        replyToMessageId: replyToMessageId,
      );

      await collection.doc(messageId).set(message.toMap());
      await _updateChatActivity(context, chatRoomId, messageId, content);

      return message;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  /// Send a system message
  Future<ChatMessage> sendSystemMessage({
    required ChatContext context,
    required String chatRoomId,
    required String content,
  }) async {
    try {
      final collection = _chatCollection(context, chatRoomId);
      final String messageId = collection.doc().id;

      final ChatMessage message = ChatMessage.createSystemMessage(
        chatRoomId: chatRoomId,
        context: context,
        content: content,
        messageId: messageId,
      );

      await collection.doc(messageId).set(message.toMap());
      await _updateChatActivity(context, chatRoomId, messageId, content);

      return message;
    } catch (e) {
      throw Exception('Failed to send system message: $e');
    }
  }

  /// Mark messages as read by a user
  Future<void> markMessagesAsRead(
    ChatContext context,
    String chatRoomId,
    String userId,
  ) async {
    try {
      final unreadMessages = await _chatCollection(context, chatRoomId)
          .where('readBy', whereNotIn: [userId]).get();

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

  /// Get unread message count for a user
  Future<int> getUnreadCount(
    ChatContext context,
    String chatRoomId,
    String userId,
  ) async {
    try {
      final unreadMessages = await _chatCollection(context, chatRoomId)
          .where('readBy', whereNotIn: [userId])
          .where('senderId', isNotEqualTo: userId)
          .get();

      return unreadMessages.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Edit a message (only by sender)
  Future<void> editMessage({
    required ChatContext context,
    required String chatRoomId,
    required String messageId,
    required String newContent,
    required String userId,
  }) async {
    try {
      final messageDoc =
          await _chatCollection(context, chatRoomId).doc(messageId).get();

      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final message = ChatMessage.fromMap(messageDoc.data()!, context: context);
      if (message.senderId != userId) {
        throw Exception('You can only edit your own messages');
      }

      await _chatCollection(context, chatRoomId).doc(messageId).update({
        'content': newContent,
        'isEdited': true,
        'editedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to edit message: $e');
    }
  }

  /// Delete a message (only by sender)
  Future<void> deleteMessage({
    required ChatContext context,
    required String chatRoomId,
    required String messageId,
    required String userId,
  }) async {
    try {
      final messageDoc =
          await _chatCollection(context, chatRoomId).doc(messageId).get();

      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final message = ChatMessage.fromMap(messageDoc.data()!, context: context);
      if (message.senderId != userId) {
        throw Exception('You can only delete your own messages');
      }

      await _chatCollection(context, chatRoomId).doc(messageId).delete();
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  /// Initialize chat when first created
  Future<void> initializeChat(ChatContext context, String chatRoomId) async {
    try {
      final existingMessages = await _chatCollection(context, chatRoomId)
          .limit(1)
          .get();

      if (existingMessages.docs.isEmpty) {
        final welcomeMessage = context == ChatContext.hangout
            ? 'Welcome to the group chat! Use this space to coordinate your plans.'
            : 'Welcome! You\'ve been matched. Start a conversation!';

        await sendSystemMessage(
          context: context,
          chatRoomId: chatRoomId,
          content: welcomeMessage,
        );
      }
    } catch (e) {
      print('Failed to initialize chat: $e');
    }
  }

  /// Initialize a matched group chat with conversation starter
  Future<void> initializeMatchedGroupChat(
    String chatRoomId,
    String conversationStarter,
  ) async {
    try {
      final existingMessages = await _chatCollection(
        ChatContext.matchedGroup,
        chatRoomId,
      ).limit(1).get();

      if (existingMessages.docs.isEmpty) {
        final collection = _chatCollection(ChatContext.matchedGroup, chatRoomId);
        final String messageId = collection.doc().id;

        final message = ChatMessage.matchCreatedMessage(
          chatRoomId: chatRoomId,
          conversationStarter: conversationStarter,
          messageId: messageId,
        );

        await collection.doc(messageId).set(message.toMap());
      }
    } catch (e) {
      print('Failed to initialize matched group chat: $e');
    }
  }

  /// Handle user joining (send system message)
  Future<void> handleUserJoined({
    required ChatContext context,
    required String chatRoomId,
    required String userName,
  }) async {
    try {
      await sendSystemMessage(
        context: context,
        chatRoomId: chatRoomId,
        content: '$userName joined the group',
      );
    } catch (e) {
      print('Failed to send user joined message: $e');
    }
  }

  /// Handle user leaving (send system message)
  Future<void> handleUserLeft({
    required ChatContext context,
    required String chatRoomId,
    required String userName,
  }) async {
    try {
      await sendSystemMessage(
        context: context,
        chatRoomId: chatRoomId,
        content: '$userName left the group',
      );
    } catch (e) {
      print('Failed to send user left message: $e');
    }
  }

  /// Archive chat (make it read-only)
  Future<void> archiveChat(ChatContext context, String chatRoomId) async {
    try {
      await sendSystemMessage(
        context: context,
        chatRoomId: chatRoomId,
        content: context == ChatContext.hangout
            ? 'This event has ended. Chat is now read-only.'
            : 'This group has been archived. Chat is now read-only.',
      );
    } catch (e) {
      print('Failed to archive chat: $e');
    }
  }

  /// Check if user has permission to access this chat
  Future<bool> canAccessChat(
    ChatContext context,
    String chatRoomId,
    String userId,
  ) async {
    try {
      final doc = await _parentDocument(context, chatRoomId).get();
      if (!doc.exists) return false;

      switch (context) {
        case ChatContext.hangout:
          final post = Post.fromMap(doc.data()!);
          return post.participantIds.contains(userId);
        case ChatContext.matchedGroup:
          final group = MatchedGroupModel.fromMap(doc.data()!);
          return group.isMember(userId);
      }
    } catch (e) {
      return false;
    }
  }

  /// Check if chat is read-only
  Future<bool> isChatReadOnly(ChatContext context, String chatRoomId) async {
    try {
      final doc = await _parentDocument(context, chatRoomId).get();
      if (!doc.exists) return true;

      switch (context) {
        case ChatContext.hangout:
          final post = Post.fromMap(doc.data()!);
          return post.status == PostStatus.completed;
        case ChatContext.matchedGroup:
          final group = MatchedGroupModel.fromMap(doc.data()!);
          return group.isArchived;
      }
    } catch (e) {
      return true;
    }
  }

  /// Clean up old chats (for hangouts only)
  Future<void> cleanupOldHangoutChats() async {
    try {
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

      final oldPosts = await _firestore
          .collection('posts')
          .where('status', isEqualTo: PostStatus.completed.name)
          .where('lastChatActivity', isLessThan: Timestamp.fromDate(oneWeekAgo))
          .get();

      final batch = _firestore.batch();
      for (final postDoc in oldPosts.docs) {
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

  /// Update chat activity metadata on parent document
  Future<void> _updateChatActivity(
    ChatContext context,
    String chatRoomId,
    String messageId,
    String messagePreview,
  ) async {
    try {
      final updateData = <String, dynamic>{
        'lastChatActivity': Timestamp.fromDate(DateTime.now()),
      };

      switch (context) {
        case ChatContext.hangout:
          updateData['lastChatMessageId'] = messageId;
          break;
        case ChatContext.matchedGroup:
          updateData['lastMessageId'] = messageId;
          updateData['lastMessageTime'] = Timestamp.fromDate(DateTime.now());
          updateData['lastMessagePreview'] = messagePreview.length > 50
              ? '${messagePreview.substring(0, 50)}...'
              : messagePreview;
          break;
      }

      await _parentDocument(context, chatRoomId).update(updateData);
    } catch (e) {
      print('Failed to update chat activity: $e');
    }
  }
}
