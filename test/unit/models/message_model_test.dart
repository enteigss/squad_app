import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:squad_app/models/message_model.dart';

void main() {
  group('MessageModel', () {
    final fixedDate = DateTime(2024, 1, 1, 12, 0, 0);

    MessageModel createTestMessage({
      String id = 'msg-123',
      String groupId = 'group-123',
      String senderId = 'user-123',
      String senderName = 'Test User',
      String? senderAvatar,
      String content = 'Hello world',
      MessageType type = MessageType.text,
      List<String> readBy = const ['user-123'],
      String? imageUrl,
      bool isEdited = false,
    }) {
      return MessageModel(
        id: id,
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        content: content,
        type: type,
        timestamp: fixedDate,
        readBy: readBy,
        imageUrl: imageUrl,
        isEdited: isEdited,
      );
    }

    group('fromMap', () {
      test('creates MessageModel from valid map with int timestamp', () {
        final map = {
          'id': 'msg-123',
          'groupId': 'group-123',
          'senderId': 'user-123',
          'senderName': 'Test User',
          'senderAvatar': 'https://example.com/avatar.jpg',
          'content': 'Hello world',
          'type': 'text',
          'timestamp': fixedDate.millisecondsSinceEpoch,
          'readBy': ['user-123', 'user-456'],
          'imageUrl': null,
          'fileName': null,
          'fileSize': null,
          'isEdited': false,
          'editedAt': null,
          'replyToMessageId': null,
        };

        final message = MessageModel.fromMap(map);

        expect(message.id, 'msg-123');
        expect(message.groupId, 'group-123');
        expect(message.senderId, 'user-123');
        expect(message.senderName, 'Test User');
        expect(message.senderAvatar, 'https://example.com/avatar.jpg');
        expect(message.content, 'Hello world');
        expect(message.type, MessageType.text);
        expect(message.readBy, ['user-123', 'user-456']);
        expect(message.isEdited, false);
      });

      test('creates MessageModel from Firestore Timestamp', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('messages').doc('test').set({
          'id': 'msg-123',
          'groupId': 'group-123',
          'senderId': 'user-123',
          'senderName': 'Test User',
          'content': 'Hello',
          'type': 'text',
          'timestamp': Timestamp.fromDate(fixedDate),
          'readBy': [],
        });

        final doc = await firestore.collection('messages').doc('test').get();
        final message = MessageModel.fromMap(doc.data()!);

        expect(message.id, 'msg-123');
        expect(message.timestamp, fixedDate);
      });

      test('handles all MessageType values', () {
        for (final type in MessageType.values) {
          final map = {
            'id': 'msg-123',
            'groupId': 'group-123',
            'senderId': 'user-123',
            'senderName': 'Test',
            'content': 'Test',
            'type': type.toString().split('.').last,
            'timestamp': fixedDate.millisecondsSinceEpoch,
            'readBy': [],
          };

          final message = MessageModel.fromMap(map);
          expect(message.type, type);
        }
      });

      test('handles missing optional fields', () {
        final map = {
          'id': 'msg-123',
          'groupId': 'group-123',
          'senderId': 'user-123',
          'senderName': 'Test',
          'content': 'Hello',
          'timestamp': fixedDate.millisecondsSinceEpoch,
        };

        final message = MessageModel.fromMap(map);

        expect(message.senderAvatar, isNull);
        expect(message.imageUrl, isNull);
        expect(message.fileName, isNull);
        expect(message.fileSize, isNull);
        expect(message.isEdited, false);
        expect(message.editedAt, isNull);
        expect(message.replyToMessageId, isNull);
        expect(message.type, MessageType.text);
        expect(message.readBy, isEmpty);
      });

      test('handles null/missing sender fields with defaults', () {
        final map = {
          'id': 'msg-123',
          'groupId': 'group-123',
          'senderId': null,
          'senderName': null,
          'content': 'Hello',
          'timestamp': fixedDate.millisecondsSinceEpoch,
        };

        final message = MessageModel.fromMap(map);

        expect(message.senderId, 'unknown');
        expect(message.senderName, 'unknown user');
      });

      test('handles image message', () {
        final map = {
          'id': 'msg-123',
          'groupId': 'group-123',
          'senderId': 'user-123',
          'senderName': 'Test',
          'content': 'Check this out',
          'type': 'image',
          'timestamp': fixedDate.millisecondsSinceEpoch,
          'readBy': [],
          'imageUrl': 'https://example.com/image.jpg',
        };

        final message = MessageModel.fromMap(map);

        expect(message.type, MessageType.image);
        expect(message.imageUrl, 'https://example.com/image.jpg');
      });

      test('handles edited message', () {
        final editedAt = fixedDate.add(const Duration(minutes: 5));
        final map = {
          'id': 'msg-123',
          'groupId': 'group-123',
          'senderId': 'user-123',
          'senderName': 'Test',
          'content': 'Edited content',
          'timestamp': fixedDate.millisecondsSinceEpoch,
          'readBy': [],
          'isEdited': true,
          'editedAt': editedAt.millisecondsSinceEpoch,
        };

        final message = MessageModel.fromMap(map);

        expect(message.isEdited, true);
        expect(message.editedAt, editedAt);
      });
    });

    group('toMap', () {
      test('converts MessageModel to map correctly', () {
        final message = MessageModel(
          id: 'msg-123',
          groupId: 'group-123',
          senderId: 'user-123',
          senderName: 'Test User',
          senderAvatar: 'https://example.com/avatar.jpg',
          content: 'Hello world',
          type: MessageType.text,
          timestamp: fixedDate,
          readBy: ['user-123'],
          imageUrl: null,
          isEdited: false,
        );

        final map = message.toMap();

        expect(map['id'], 'msg-123');
        expect(map['groupId'], 'group-123');
        expect(map['senderId'], 'user-123');
        expect(map['senderName'], 'Test User');
        expect(map['senderAvatar'], 'https://example.com/avatar.jpg');
        expect(map['content'], 'Hello world');
        expect(map['type'], 'text');
        expect(map['timestamp'], fixedDate.millisecondsSinceEpoch);
        expect(map['readBy'], ['user-123']);
        expect(map['isEdited'], false);
      });

      test('handles image message toMap', () {
        final message = MessageModel(
          id: 'msg-123',
          groupId: 'group-123',
          senderId: 'user-123',
          senderName: 'Test',
          content: 'Image',
          type: MessageType.image,
          timestamp: fixedDate,
          imageUrl: 'https://example.com/image.jpg',
        );

        final map = message.toMap();

        expect(map['type'], 'image');
        expect(map['imageUrl'], 'https://example.com/image.jpg');
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
        expect(copy.groupId, original.groupId);
        expect(copy.senderId, original.senderId);
      });

      test('can update readBy list', () {
        final original = createTestMessage(readBy: ['user-123']);
        final copy = original.copyWith(
          readBy: ['user-123', 'user-456'],
        );

        expect(copy.readBy, ['user-123', 'user-456']);
      });
    });

    group('isReadBy', () {
      test('returns true when user has read message', () {
        final message = createTestMessage(readBy: ['user-123', 'user-456']);

        expect(message.isReadBy('user-123'), true);
        expect(message.isReadBy('user-456'), true);
      });

      test('returns false when user has not read message', () {
        final message = createTestMessage(readBy: ['user-123']);

        expect(message.isReadBy('user-456'), false);
      });
    });

    group('roundtrip serialization', () {
      test('toMap then fromMap produces equivalent object', () {
        final original = MessageModel(
          id: 'msg-123',
          groupId: 'group-123',
          senderId: 'user-123',
          senderName: 'Test User',
          senderAvatar: 'https://example.com/avatar.jpg',
          content: 'Hello world',
          type: MessageType.text,
          timestamp: fixedDate,
          readBy: ['user-123', 'user-456'],
          isEdited: true,
          editedAt: fixedDate.add(const Duration(minutes: 5)),
          replyToMessageId: 'msg-000',
        );

        final map = original.toMap();
        final restored = MessageModel.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.groupId, original.groupId);
        expect(restored.senderId, original.senderId);
        expect(restored.senderName, original.senderName);
        expect(restored.content, original.content);
        expect(restored.type, original.type);
        expect(restored.readBy, original.readBy);
        expect(restored.isEdited, original.isEdited);
        expect(restored.replyToMessageId, original.replyToMessageId);
      });
    });
  });
}
