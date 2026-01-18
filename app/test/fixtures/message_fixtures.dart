import 'package:squad_app/models/message_model.dart';
import 'package:squad_app/models/group_model.dart';
import 'user_fixtures.dart';

/// Test fixtures for MessageModel and GroupModel
///
/// Usage:
/// ```dart
/// final message = MessageFixtures.textMessage;
/// final group = MessageFixtures.basicGroup;
/// ```
class MessageFixtures {
  static final DateTime _fixedDate = DateTime(2024, 1, 1, 12, 0, 0);

  // ============ Messages ============

  /// A basic text message
  static MessageModel get textMessage => MessageModel(
        id: 'msg-123',
        groupId: 'group-123',
        senderId: UserFixtures.basicUser.id,
        senderName: UserFixtures.basicUser.displayName!,
        senderAvatar: UserFixtures.basicUser.photoUrl,
        content: 'Hello everyone!',
        type: MessageType.text,
        timestamp: _fixedDate,
        readBy: [UserFixtures.basicUser.id],
      );

  /// A message from another user
  static MessageModel get replyMessage => MessageModel(
        id: 'msg-456',
        groupId: 'group-123',
        senderId: UserFixtures.secondUser.id,
        senderName: UserFixtures.secondUser.displayName!,
        content: 'Hey! How are you?',
        type: MessageType.text,
        timestamp: _fixedDate.add(const Duration(minutes: 1)),
        readBy: [UserFixtures.secondUser.id, UserFixtures.basicUser.id],
      );

  /// An image message
  static MessageModel get imageMessage => MessageModel(
        id: 'msg-789',
        groupId: 'group-123',
        senderId: UserFixtures.basicUser.id,
        senderName: UserFixtures.basicUser.displayName!,
        content: 'Check this out!',
        type: MessageType.image,
        timestamp: _fixedDate.add(const Duration(minutes: 2)),
        imageUrl: 'https://example.com/image.jpg',
        readBy: [UserFixtures.basicUser.id],
      );

  /// An edited message
  static MessageModel get editedMessage => MessageModel(
        id: 'msg-edited',
        groupId: 'group-123',
        senderId: UserFixtures.basicUser.id,
        senderName: UserFixtures.basicUser.displayName!,
        content: 'This message was edited',
        type: MessageType.text,
        timestamp: _fixedDate,
        isEdited: true,
        editedAt: _fixedDate.add(const Duration(minutes: 5)),
        readBy: [UserFixtures.basicUser.id],
      );

  /// A system message
  static MessageModel get systemMessage => MessageModel(
        id: 'msg-system',
        groupId: 'group-123',
        senderId: 'system',
        senderName: 'System',
        content: 'User joined the group',
        type: MessageType.system,
        timestamp: _fixedDate,
        readBy: [],
      );

  /// A message from a blocked user (for testing filtering)
  static MessageModel get blockedUserMessage => MessageModel(
        id: 'msg-blocked',
        groupId: 'group-123',
        senderId: 'user-blocked',
        senderName: 'Blocked User',
        content: 'This should be filtered',
        type: MessageType.text,
        timestamp: _fixedDate,
        readBy: [],
      );

  /// List of messages for testing chat history
  static List<MessageModel> get chatHistory => [
        textMessage,
        replyMessage,
        imageMessage,
      ];

  // ============ Groups ============

  /// A basic chat group
  static GroupModel get basicGroup => GroupModel(
        id: 'group-123',
        name: 'Test Group',
        description: 'A test group for unit tests',
        createdAt: _fixedDate,
        memberIds: [UserFixtures.basicUser.id, UserFixtures.secondUser.id],
        adminIds: [UserFixtures.basicUser.id],
        lastMessageId: textMessage.id,
        lastMessageTime: textMessage.timestamp,
      );

  /// A group with just one member
  static GroupModel get singleMemberGroup => GroupModel(
        id: 'group-single',
        name: 'Solo Group',
        createdAt: _fixedDate,
        memberIds: [UserFixtures.basicUser.id],
        adminIds: [UserFixtures.basicUser.id],
      );

  /// A group with multiple admins
  static GroupModel get multiAdminGroup => GroupModel(
        id: 'group-multi-admin',
        name: 'Multi Admin Group',
        createdAt: _fixedDate,
        memberIds: [
          UserFixtures.basicUser.id,
          UserFixtures.secondUser.id,
          UserFixtures.userWhoBlocked.id,
        ],
        adminIds: [UserFixtures.basicUser.id, UserFixtures.secondUser.id],
      );

  /// Creates a custom message
  static MessageModel customMessage({
    String? id,
    String? groupId,
    String? senderId,
    String? senderName,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    List<String>? readBy,
  }) {
    return textMessage.copyWith(
      id: id,
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      type: type,
      timestamp: timestamp,
      readBy: readBy,
    );
  }

  /// Creates a custom group
  static GroupModel customGroup({
    String? id,
    String? name,
    List<String>? memberIds,
    List<String>? adminIds,
  }) {
    return basicGroup.copyWith(
      id: id,
      name: name,
      memberIds: memberIds,
      adminIds: adminIds,
    );
  }
}
