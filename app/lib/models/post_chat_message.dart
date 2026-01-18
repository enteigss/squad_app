import 'package:cloud_firestore/cloud_firestore.dart';

enum PostChatMessageType { text, image, system }

class PostChatMessage {
  final String id;
  final String postId;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String content;
  final PostChatMessageType type;
  final DateTime timestamp;
  final List<String> readBy;
  final String? imageUrl;
  final bool isEdited;
  final DateTime? editedAt;

  PostChatMessage({
    required this.id,
    required this.postId,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.content,
    this.type = PostChatMessageType.text,
    required this.timestamp,
    this.readBy = const [],
    this.imageUrl,
    this.isEdited = false,
    this.editedAt,
  });

  factory PostChatMessage.fromMap(Map<String, dynamic> map) {
    return PostChatMessage(
      id: map['id'] ?? '',
      postId: map['postId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderPhotoUrl: map['senderPhotoUrl'],
      content: map['content'] ?? '',
      type: PostChatMessageType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => PostChatMessageType.text,
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      readBy: List<String>.from(map['readBy'] ?? []),
      imageUrl: map['imageUrl'],
      isEdited: map['isEdited'] ?? false,
      editedAt: map['editedAt'] != null
          ? (map['editedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
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
    };
  }

  PostChatMessage copyWith({
    String? id,
    String? postId,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    String? content,
    PostChatMessageType? type,
    DateTime? timestamp,
    List<String>? readBy,
    String? imageUrl,
    bool? isEdited,
    DateTime? editedAt,
  }) {
    return PostChatMessage(
      id: id ?? this.id,
      postId: postId ?? this.postId,
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
    );
  }

  // Helper methods
  bool isReadBy(String userId) => readBy.contains(userId);
  
  bool isSentBy(String userId) => senderId == userId;
  
  // Create system messages for post events
  static PostChatMessage createSystemMessage({
    required String postId,
    required String content,
    String? messageId,
  }) {
    return PostChatMessage(
      id: messageId ?? '',
      postId: postId,
      senderId: 'system',
      senderName: 'System',
      content: content,
      type: PostChatMessageType.system,
      timestamp: DateTime.now(),
      readBy: [],
    );
  }

  // Create user joined message
  static PostChatMessage userJoinedMessage({
    required String postId,
    required String userName,
    String? messageId,
  }) {
    return createSystemMessage(
      postId: postId,
      content: '$userName joined the group',
      messageId: messageId,
    );
  }

  // Create user left message
  static PostChatMessage userLeftMessage({
    required String postId,
    required String userName,
    String? messageId,
  }) {
    return createSystemMessage(
      postId: postId,
      content: '$userName left the group',
      messageId: messageId,
    );
  }
}