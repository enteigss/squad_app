import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, file, system }

class MessageModel {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final List<String> readBy;
  final String? imageUrl;
  final String? fileName;
  final int? fileSize;
  final bool isEdited;
  final DateTime? editedAt;
  final String? replyToMessageId;

  MessageModel({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    this.type = MessageType.text,
    required this.timestamp,
    this.readBy = const [],
    this.imageUrl,
    this.fileName,
    this.fileSize,
    this.isEdited = false,
    this.editedAt,
    this.replyToMessageId,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      groupId: map['groupId'] ?? '',
      senderId: map['senderId'] ?? 'unknown',
      senderName: map['senderName'] ?? 'unknown user',
      senderAvatar: map['senderAvatar'],
      content: map['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${map['type']}',
        orElse: () => MessageType.text,
      ),
      timestamp: map['timestamp'] != null
          ? _parseTimestamp(map['timestamp'])
          : DateTime.now(),
      readBy: List<String>.from(map['readBy'] ?? []),
      imageUrl: map['imageUrl'],
      fileName: map['fileName'],
      fileSize: map['fileSize'],
      isEdited: map['isEdited'] ?? false,
      editedAt: map['editedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['editedAt'])
          : null,
      replyToMessageId: map['replyToMessageId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'type': type.toString().split('.').last,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'readBy': readBy,
      'imageUrl': imageUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'isEdited': isEdited,
      'editedAt': editedAt?.millisecondsSinceEpoch,
      'replyToMessageId': replyToMessageId,
    };
  }

  MessageModel copyWith({
    String? id,
    String? groupId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    List<String>? readBy,
    String? imageUrl,
    String? fileName,
    int? fileSize,
    bool? isEdited,
    DateTime? editedAt,
    String? replyToMessageId,
  }) {
    return MessageModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      readBy: readBy ?? this.readBy,
      imageUrl: imageUrl ?? this.imageUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
    );
  }

  bool isReadBy(String userId) {
    return readBy.contains(userId);
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is int) {
      // Integer timestamp (milliseconds since epoch)
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is Timestamp) {
      // Firebase Timestamp object
      return timestamp.toDate();
    } else {
      // Fallback to current time
      return DateTime.now();
    }
  }
}
