import '../models/chat_message.dart';
import '../models/post_chat_message.dart';
import 'chat_service.dart';

/// Wrapper for backward compatibility.
/// Use ChatService directly for new code.
@Deprecated('Use ChatService instead')
class PostChatService {
  static final PostChatService _instance = PostChatService._internal();
  factory PostChatService() => _instance;
  PostChatService._internal();

  final ChatService _chatService = ChatService();

  /// Get real-time stream of messages for a post's chat
  /// Returns PostChatMessage for backward compatibility
  Stream<List<PostChatMessage>> getChatMessages(String postId) {
    return _chatService.getMessages(ChatContext.hangout, postId).map(
      (messages) => messages.map(_toPostChatMessage).toList(),
    );
  }

  /// Send a text message to the post chat
  Future<PostChatMessage> sendMessage({
    required String postId,
    required String senderId,
    required String senderName,
    required String content,
    String? senderPhotoUrl,
    PostChatMessageType type = PostChatMessageType.text,
    String? imageUrl,
  }) async {
    final message = await _chatService.sendMessage(
      context: ChatContext.hangout,
      chatRoomId: postId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      senderPhotoUrl: senderPhotoUrl,
      type: _toChatMessageType(type),
      imageUrl: imageUrl,
    );
    return _toPostChatMessage(message);
  }

  /// Send system message
  Future<PostChatMessage> sendSystemMessage({
    required String postId,
    required String content,
  }) async {
    final message = await _chatService.sendSystemMessage(
      context: ChatContext.hangout,
      chatRoomId: postId,
      content: content,
    );
    return _toPostChatMessage(message);
  }

  /// Mark messages as read by a user
  Future<void> markMessagesAsRead(String postId, String userId) {
    return _chatService.markMessagesAsRead(ChatContext.hangout, postId, userId);
  }

  /// Get unread message count
  Future<int> getUnreadCount(String postId, String userId) {
    return _chatService.getUnreadCount(ChatContext.hangout, postId, userId);
  }

  /// Edit a message
  Future<void> editMessage({
    required String postId,
    required String messageId,
    required String newContent,
    required String userId,
  }) {
    return _chatService.editMessage(
      context: ChatContext.hangout,
      chatRoomId: postId,
      messageId: messageId,
      newContent: newContent,
      userId: userId,
    );
  }

  /// Delete a message
  Future<void> deleteMessage({
    required String postId,
    required String messageId,
    required String userId,
  }) {
    return _chatService.deleteMessage(
      context: ChatContext.hangout,
      chatRoomId: postId,
      messageId: messageId,
      userId: userId,
    );
  }

  /// Initialize chat when first user joins
  Future<void> initializeChat(String postId) {
    return _chatService.initializeChat(ChatContext.hangout, postId);
  }

  /// Handle user joining post
  Future<void> handleUserJoined({
    required String postId,
    required String userName,
  }) {
    return _chatService.handleUserJoined(
      context: ChatContext.hangout,
      chatRoomId: postId,
      userName: userName,
    );
  }

  /// Handle user leaving post
  Future<void> handleUserLeft({
    required String postId,
    required String userName,
  }) {
    return _chatService.handleUserLeft(
      context: ChatContext.hangout,
      chatRoomId: postId,
      userName: userName,
    );
  }

  /// Archive chat when post is completed
  Future<void> archiveChat(String postId) {
    return _chatService.archiveChat(ChatContext.hangout, postId);
  }

  /// Clean up old chats
  Future<void> cleanupOldChats() {
    return _chatService.cleanupOldHangoutChats();
  }

  /// Check if user can access chat
  Future<bool> canAccessChat(String postId, String userId) {
    return _chatService.canAccessChat(ChatContext.hangout, postId, userId);
  }

  /// Check if chat is read-only
  Future<bool> isChatReadOnly(String postId) {
    return _chatService.isChatReadOnly(ChatContext.hangout, postId);
  }

  // Conversion helpers

  PostChatMessage _toPostChatMessage(ChatMessage msg) {
    return PostChatMessage(
      id: msg.id,
      postId: msg.chatRoomId,
      senderId: msg.senderId,
      senderName: msg.senderName,
      senderPhotoUrl: msg.senderPhotoUrl,
      content: msg.content,
      type: _toPostChatMessageType(msg.type),
      timestamp: msg.timestamp,
      readBy: msg.readBy,
      imageUrl: msg.imageUrl,
      isEdited: msg.isEdited,
      editedAt: msg.editedAt,
    );
  }

  PostChatMessageType _toPostChatMessageType(ChatMessageType type) {
    switch (type) {
      case ChatMessageType.text:
        return PostChatMessageType.text;
      case ChatMessageType.image:
        return PostChatMessageType.image;
      case ChatMessageType.system:
        return PostChatMessageType.system;
    }
  }

  ChatMessageType _toChatMessageType(PostChatMessageType type) {
    switch (type) {
      case PostChatMessageType.text:
        return ChatMessageType.text;
      case PostChatMessageType.image:
        return ChatMessageType.image;
      case PostChatMessageType.system:
        return ChatMessageType.system;
    }
  }
}
