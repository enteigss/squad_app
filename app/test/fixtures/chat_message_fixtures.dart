import 'package:squad_app/models/chat_message.dart';

/// Test fixtures for ChatMessage
///
/// Usage:
/// ```dart
/// final msg = ChatMessageFixtures.ownTextMessage;
/// final other = ChatMessageFixtures.otherTextMessage;
/// ```
class ChatMessageFixtures {
  static final DateTime _fixedDate = DateTime(2024, 1, 1, 12, 0, 0);

  static const String currentUserId = 'user-123';
  static const String currentUserName = 'Test User';
  static const String currentUserPhotoUrl = 'https://example.com/photo.jpg';
  static const String otherUserId = 'user-456';
  static const String otherUserName = 'Second User';
  static const String otherUserPhotoUrl =
      'https://example.com/other-photo.jpg';

  /// A text message from the current user (own message)
  static ChatMessage get ownTextMessage => ChatMessage(
        id: 'msg-own-1',
        chatRoomId: 'room-123',
        context: ChatContext.hangout,
        senderId: currentUserId,
        senderName: currentUserName,
        senderPhotoUrl: currentUserPhotoUrl,
        content: 'Hello everyone!',
        type: ChatMessageType.text,
        timestamp: _fixedDate,
        readBy: [currentUserId],
      );

  /// A text message from another user (with photo)
  static ChatMessage get otherTextMessage => ChatMessage(
        id: 'msg-other-1',
        chatRoomId: 'room-123',
        context: ChatContext.hangout,
        senderId: otherUserId,
        senderName: otherUserName,
        senderPhotoUrl: otherUserPhotoUrl,
        content: 'Hey there!',
        type: ChatMessageType.text,
        timestamp: _fixedDate,
        readBy: [otherUserId],
      );

  /// A text message from another user without a photo URL
  static ChatMessage get otherTextMessageNoPhoto => ChatMessage(
        id: 'msg-other-nophoto',
        chatRoomId: 'room-123',
        context: ChatContext.hangout,
        senderId: otherUserId,
        senderName: otherUserName,
        senderPhotoUrl: null,
        content: 'No photo message',
        type: ChatMessageType.text,
        timestamp: _fixedDate,
        readBy: [otherUserId],
      );

  /// An edited message from another user
  static ChatMessage get editedMessage => ChatMessage(
        id: 'msg-edited-1',
        chatRoomId: 'room-123',
        context: ChatContext.hangout,
        senderId: otherUserId,
        senderName: otherUserName,
        content: 'This was edited',
        type: ChatMessageType.text,
        timestamp: _fixedDate,
        readBy: [otherUserId],
        isEdited: true,
        editedAt: _fixedDate.add(const Duration(minutes: 5)),
      );

  /// An edited message from the current user
  static ChatMessage get ownEditedMessage => ChatMessage(
        id: 'msg-own-edited',
        chatRoomId: 'room-123',
        context: ChatContext.hangout,
        senderId: currentUserId,
        senderName: currentUserName,
        senderPhotoUrl: currentUserPhotoUrl,
        content: 'I edited this',
        type: ChatMessageType.text,
        timestamp: _fixedDate,
        readBy: [currentUserId],
        isEdited: true,
        editedAt: _fixedDate.add(const Duration(minutes: 3)),
      );

  /// A system message
  static ChatMessage get systemMessage => ChatMessage(
        id: 'msg-system-1',
        chatRoomId: 'room-123',
        context: ChatContext.hangout,
        senderId: 'system',
        senderName: 'System',
        content: 'Alice joined the group',
        type: ChatMessageType.system,
        timestamp: _fixedDate,
        readBy: [],
      );

  /// A censored/blocked message
  static ChatMessage get censoredMessage => ChatMessage(
        id: 'msg-blocked-1',
        chatRoomId: 'room-123',
        context: ChatContext.hangout,
        senderId: 'user-blocked',
        senderName: 'Blocked User',
        content: 'CENSORED_MESSAGE',
        type: ChatMessageType.text,
        timestamp: _fixedDate,
        readBy: ['user-blocked'],
      );

  /// Creates a custom message with specified overrides
  static ChatMessage custom({
    String? id,
    String? chatRoomId,
    ChatContext? context,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    String? content,
    ChatMessageType? type,
    DateTime? timestamp,
    List<String>? readBy,
    String? imageUrl,
    bool? isEdited,
    DateTime? editedAt,
  }) {
    return ownTextMessage.copyWith(
      id: id,
      chatRoomId: chatRoomId,
      context: context,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      content: content,
      type: type,
      timestamp: timestamp,
      readBy: readBy,
      imageUrl: imageUrl,
      isEdited: isEdited,
      editedAt: editedAt,
    );
  }
}
