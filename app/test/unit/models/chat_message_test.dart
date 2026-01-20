import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:squad_app/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    final fixedDate = DateTime(2024, 1, 1, 12, 0, 0);

    ChatMessage createTestMessage({
      String id = 'msg-123',
      String chatRoomId = 'room-123',
      ChatContext context = ChatContext.hangout,
      String senderId = 'user-123',
      String senderName = 'Test User',
      String? senderPhotoUrl,
      String content = 'Hello',
      ChatMessageType type = ChatMessageType.text,
      List<String> readBy = const ['user-123'],
      String? imageUrl,
      bool isEdited = false,
      String? replyToMessageId,
    }) {
      return ChatMessage(
        id: id,
        chatRoomId: chatRoomId,
        context: context,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        content: content,
        type: type,
        timestamp: fixedDate,
        readBy: readBy,
        imageUrl: imageUrl,
        isEdited: isEdited,
        replyToMessageId: replyToMessageId,
      );
    }

    group('fromMap', () {
      test('creates ChatMessage from valid map with Timestamp (hangout)', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('messages').doc('test').set({
          'id': 'msg-123',
          'chatRoomId': 'room-123',
          'senderId': 'user-123',
          'senderName': 'Test User',
          'senderPhotoUrl': 'https://example.com/photo.jpg',
          'content': 'Hello everyone',
          'type': 'text',
          'timestamp': Timestamp.fromDate(fixedDate),
          'readBy': ['user-123', 'user-456'],
          'imageUrl': null,
          'isEdited': false,
        });

        final doc = await firestore.collection('messages').doc('test').get();
        final message =
            ChatMessage.fromMap(doc.data()!, context: ChatContext.hangout);

        expect(message.id, 'msg-123');
        expect(message.chatRoomId, 'room-123');
        expect(message.context, ChatContext.hangout);
        expect(message.senderId, 'user-123');
        expect(message.senderName, 'Test User');
        expect(message.senderPhotoUrl, 'https://example.com/photo.jpg');
        expect(message.content, 'Hello everyone');
        expect(message.type, ChatMessageType.text);
        expect(message.readBy, ['user-123', 'user-456']);
        expect(message.isEdited, false);
      });

      test('creates ChatMessage with matchedGroup context', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('messages').doc('test').set({
          'id': 'msg-123',
          'chatRoomId': 'group-123',
          'senderId': 'user-123',
          'senderName': 'Test User',
          'content': 'Hello matched group!',
          'type': 'text',
          'timestamp': Timestamp.fromDate(fixedDate),
          'readBy': [],
        });

        final doc = await firestore.collection('messages').doc('test').get();
        final message =
            ChatMessage.fromMap(doc.data()!, context: ChatContext.matchedGroup);

        expect(message.context, ChatContext.matchedGroup);
        expect(message.chatRoomId, 'group-123');
      });

      test('handles all ChatMessageType values', () async {
        final firestore = FakeFirebaseFirestore();

        for (final type in ChatMessageType.values) {
          await firestore.collection('messages').doc(type.name).set({
            'id': type.name,
            'chatRoomId': 'room-123',
            'senderId': 'user-123',
            'senderName': 'Test',
            'content': 'Test',
            'type': type.name,
            'timestamp': Timestamp.fromDate(fixedDate),
            'readBy': [],
          });

          final doc =
              await firestore.collection('messages').doc(type.name).get();
          final message =
              ChatMessage.fromMap(doc.data()!, context: ChatContext.hangout);
          expect(message.type, type);
        }
      });

      test('handles missing optional fields', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('messages').doc('test').set({
          'id': 'msg-123',
          'chatRoomId': 'room-123',
          'senderId': 'user-123',
          'senderName': 'Test',
          'content': 'Hello',
          'timestamp': Timestamp.fromDate(fixedDate),
        });

        final doc = await firestore.collection('messages').doc('test').get();
        final message =
            ChatMessage.fromMap(doc.data()!, context: ChatContext.hangout);

        expect(message.senderPhotoUrl, isNull);
        expect(message.imageUrl, isNull);
        expect(message.isEdited, false);
        expect(message.editedAt, isNull);
        expect(message.type, ChatMessageType.text);
        expect(message.readBy, isEmpty);
        expect(message.replyToMessageId, isNull);
      });

      test('handles image message', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('messages').doc('test').set({
          'id': 'msg-123',
          'chatRoomId': 'room-123',
          'senderId': 'user-123',
          'senderName': 'Test',
          'content': 'Check this',
          'type': 'image',
          'timestamp': Timestamp.fromDate(fixedDate),
          'readBy': [],
          'imageUrl': 'https://example.com/image.jpg',
        });

        final doc = await firestore.collection('messages').doc('test').get();
        final message =
            ChatMessage.fromMap(doc.data()!, context: ChatContext.hangout);

        expect(message.type, ChatMessageType.image);
        expect(message.imageUrl, 'https://example.com/image.jpg');
      });

      test('handles edited message', () async {
        final editedAt = fixedDate.add(const Duration(minutes: 5));
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('messages').doc('test').set({
          'id': 'msg-123',
          'chatRoomId': 'room-123',
          'senderId': 'user-123',
          'senderName': 'Test',
          'content': 'Edited content',
          'timestamp': Timestamp.fromDate(fixedDate),
          'readBy': [],
          'isEdited': true,
          'editedAt': Timestamp.fromDate(editedAt),
        });

        final doc = await firestore.collection('messages').doc('test').get();
        final message =
            ChatMessage.fromMap(doc.data()!, context: ChatContext.hangout);

        expect(message.isEdited, true);
        expect(message.editedAt, editedAt);
      });

      test('handles replyToMessageId', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('messages').doc('test').set({
          'id': 'msg-123',
          'chatRoomId': 'room-123',
          'senderId': 'user-123',
          'senderName': 'Test',
          'content': 'Reply to previous',
          'timestamp': Timestamp.fromDate(fixedDate),
          'readBy': [],
          'replyToMessageId': 'msg-100',
        });

        final doc = await firestore.collection('messages').doc('test').get();
        final message =
            ChatMessage.fromMap(doc.data()!, context: ChatContext.hangout);

        expect(message.replyToMessageId, 'msg-100');
      });
    });

    group('toMap', () {
      test('converts ChatMessage to map correctly', () {
        final message = ChatMessage(
          id: 'msg-123',
          chatRoomId: 'room-123',
          context: ChatContext.hangout,
          senderId: 'user-123',
          senderName: 'Test User',
          senderPhotoUrl: 'https://example.com/photo.jpg',
          content: 'Hello',
          type: ChatMessageType.text,
          timestamp: fixedDate,
          readBy: ['user-123'],
          isEdited: false,
          replyToMessageId: 'msg-100',
        );

        final map = message.toMap();

        expect(map['id'], 'msg-123');
        expect(map['chatRoomId'], 'room-123');
        expect(map['senderId'], 'user-123');
        expect(map['senderName'], 'Test User');
        expect(map['senderPhotoUrl'], 'https://example.com/photo.jpg');
        expect(map['content'], 'Hello');
        expect(map['type'], 'text');
        expect(map['readBy'], ['user-123']);
        expect(map['isEdited'], false);
        expect(map['timestamp'], isA<Timestamp>());
        expect(map['replyToMessageId'], 'msg-100');
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = createTestMessage();
        final copy = original.copyWith(
          content: 'Updated content',
          isEdited: true,
        );

        expect(copy.content, 'Updated content');
        expect(copy.isEdited, true);
        expect(copy.id, original.id);
        expect(copy.chatRoomId, original.chatRoomId);
      });

      test('can update readBy list', () {
        final original = createTestMessage(readBy: ['user-123']);
        final copy = original.copyWith(
          readBy: ['user-123', 'user-456'],
        );

        expect(copy.readBy, ['user-123', 'user-456']);
      });

      test('can update context', () {
        final original = createTestMessage(context: ChatContext.hangout);
        final copy = original.copyWith(context: ChatContext.matchedGroup);

        expect(copy.context, ChatContext.matchedGroup);
      });
    });

    group('helper methods', () {
      test('isReadBy returns true when user has read', () {
        final message = createTestMessage(readBy: ['user-123', 'user-456']);

        expect(message.isReadBy('user-123'), true);
        expect(message.isReadBy('user-456'), true);
        expect(message.isReadBy('user-789'), false);
      });

      test('isSentBy returns true for sender', () {
        final message = createTestMessage(senderId: 'user-123');

        expect(message.isSentBy('user-123'), true);
        expect(message.isSentBy('user-456'), false);
      });

      test('isSystemMessage returns true for system messages', () {
        final systemMessage = createTestMessage(type: ChatMessageType.system);
        final textMessage = createTestMessage(type: ChatMessageType.text);

        expect(systemMessage.isSystemMessage, true);
        expect(textMessage.isSystemMessage, false);
      });
    });

    group('static factory methods', () {
      test('createSystemMessage creates system message for hangout', () {
        final message = ChatMessage.createSystemMessage(
          chatRoomId: 'room-123',
          context: ChatContext.hangout,
          content: 'System notification',
          messageId: 'sys-msg-1',
        );

        expect(message.id, 'sys-msg-1');
        expect(message.chatRoomId, 'room-123');
        expect(message.context, ChatContext.hangout);
        expect(message.senderId, 'system');
        expect(message.senderName, 'System');
        expect(message.content, 'System notification');
        expect(message.type, ChatMessageType.system);
        expect(message.readBy, isEmpty);
      });

      test('createSystemMessage creates system message for matchedGroup', () {
        final message = ChatMessage.createSystemMessage(
          chatRoomId: 'group-123',
          context: ChatContext.matchedGroup,
          content: 'Group notification',
          messageId: 'sys-msg-2',
        );

        expect(message.context, ChatContext.matchedGroup);
        expect(message.chatRoomId, 'group-123');
        expect(message.type, ChatMessageType.system);
      });

      test('userJoinedMessage creates join message', () {
        final message = ChatMessage.userJoinedMessage(
          chatRoomId: 'room-123',
          context: ChatContext.hangout,
          userName: 'John',
          messageId: 'join-msg-1',
        );

        expect(message.content, 'John joined the group');
        expect(message.type, ChatMessageType.system);
        expect(message.senderId, 'system');
      });

      test('userLeftMessage creates leave message', () {
        final message = ChatMessage.userLeftMessage(
          chatRoomId: 'room-123',
          context: ChatContext.hangout,
          userName: 'John',
          messageId: 'left-msg-1',
        );

        expect(message.content, 'John left the group');
        expect(message.type, ChatMessageType.system);
        expect(message.senderId, 'system');
      });

      test('matchCreatedMessage creates match welcome message', () {
        final message = ChatMessage.matchCreatedMessage(
          chatRoomId: 'group-123',
          conversationStarter: 'What brings you here today?',
          messageId: 'match-msg-1',
        );

        expect(message.chatRoomId, 'group-123');
        expect(message.context, ChatContext.matchedGroup);
        expect(message.type, ChatMessageType.system);
        expect(message.content, contains('matched'));
        expect(message.content, contains('What brings you here today?'));
      });
    });
  });
}
