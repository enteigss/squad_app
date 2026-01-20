import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of chat messages
enum ChatMessageType { text, image, system }

/// Context types for different chat rooms
enum ChatContext { hangout, matchedGroup }

/// Unified chat message model that works for both hangout posts and matched groups
class ChatMessage {
  final String id;
  final String chatRoomId; // postId for hangouts, groupId for matched groups
  final ChatContext context;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String content;
  final ChatMessageType type;
  final DateTime timestamp;
  final List<String> readBy;
  final String? imageUrl;
  final bool isEdited;
  final DateTime? editedAt;
  final String? replyToMessageId; // For future threading support

  ChatMessage({
    required this.id,
    required this.chatRoomId,
    required this.context,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.content,
    this.type = ChatMessageType.text,
    required this.timestamp,
    this.readBy = const [],
    this.imageUrl,
    this.isEdited = false,
    this.editedAt,
    this.replyToMessageId,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, {ChatContext? context}) {
    // Determine context from map if not provided
    final ChatContext resolvedContext = context ??
        (map['context'] != null
            ? ChatContext.values.firstWhere(
                (c) => c.name == map['context'],
                orElse: () => ChatContext.hangout,
              )
            : ChatContext.hangout);

    return ChatMessage(
      id: map['id'] ?? '',
      chatRoomId: map['chatRoomId'] ?? map['postId'] ?? '', // Support legacy postId field
      context: resolvedContext,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderPhotoUrl: map['senderPhotoUrl'],
      content: map['content'] ?? '',
      type: ChatMessageType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => ChatMessageType.text,
      ),
      timestamp: _parseTimestamp(map['timestamp']),
      readBy: List<String>.from(map['readBy'] ?? []),
      imageUrl: map['imageUrl'],
      isEdited: map['isEdited'] ?? false,
      editedAt: map['editedAt'] != null ? _parseTimestamp(map['editedAt']) : null,
      replyToMessageId: map['replyToMessageId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatRoomId': chatRoomId,
      'context': context.name,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'content': content,
      'type': type.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'readBy': readBy,
      'imageUrl': imageUrl,
      'isEdited': isEdited,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'replyToMessageId': replyToMessageId,
    };
  }

  ChatMessage copyWith({
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
    String? replyToMessageId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      context: context ?? this.context,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      readBy: readBy ?? this.readBy,
      imageUrl: imageUrl ?? this.imageUrl,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
    );
  }

  // Helper methods
  bool isReadBy(String userId) => readBy.contains(userId);

  bool isSentBy(String userId) => senderId == userId;

  bool get isSystemMessage => type == ChatMessageType.system;

  /// Parse timestamp from various formats (Firestore Timestamp, int, DateTime)
  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is DateTime) {
      return value;
    }
    // Fallback for any other Timestamp-like object
    if (value.runtimeType.toString().contains('Timestamp')) {
      return (value as dynamic).toDate();
    }
    return DateTime.now();
  }

  // Static factory methods for system messages

  /// Create a generic system message
  static ChatMessage createSystemMessage({
    required String chatRoomId,
    required ChatContext context,
    required String content,
    String? messageId,
  }) {
    return ChatMessage(
      id: messageId ?? '',
      chatRoomId: chatRoomId,
      context: context,
      senderId: 'system',
      senderName: 'System',
      content: content,
      type: ChatMessageType.system,
      timestamp: DateTime.now(),
      readBy: [],
    );
  }

  /// Create a "user joined" system message
  static ChatMessage userJoinedMessage({
    required String chatRoomId,
    required ChatContext context,
    required String userName,
    String? messageId,
  }) {
    return createSystemMessage(
      chatRoomId: chatRoomId,
      context: context,
      content: '$userName joined the group',
      messageId: messageId,
    );
  }

  /// Create a "user left" system message
  static ChatMessage userLeftMessage({
    required String chatRoomId,
    required ChatContext context,
    required String userName,
    String? messageId,
  }) {
    return createSystemMessage(
      chatRoomId: chatRoomId,
      context: context,
      content: '$userName left the group',
      messageId: messageId,
    );
  }

  /// Create a "match created" system message (for matched groups)
  static ChatMessage matchCreatedMessage({
    required String chatRoomId,
    required String conversationStarter,
    String? messageId,
  }) {
    return createSystemMessage(
      chatRoomId: chatRoomId,
      context: ChatContext.matchedGroup,
      content: 'You\'ve been matched! Here\'s a conversation starter: $conversationStarter',
      messageId: messageId,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, chatRoomId: $chatRoomId, context: $context, senderId: $senderId, content: ${content.length > 20 ? '${content.substring(0, 20)}...' : content})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
