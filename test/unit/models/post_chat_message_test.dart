import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:squad_app/models/post_chat_message.dart';

void main() {
  group('PostChatMessage', () {
    final fixedDate = DateTime(2024, 1, 1, 12, 0, 0);

    PostChatMessage createTestMessage({
      String id = 'msg-123',
      String postId = 'post-123',
      String senderId = 'user-123',
      String senderName = 'Test User',
      String? senderPhotoUrl,
      String content = 'Hello',
      PostChatMessageType type = PostChatMessageType.text,
      List<String> readBy = const ['user-123'],
      String? imageUrl,
      bool isEdited = false,
    }) {
      return PostChatMessage(
        id: id,
        postId: postId,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        content: content,
        type: type,
        timestamp: fixedDate,
        readBy: readBy,
        imageUrl: imageUrl,
        isEdited: isEdited,
      );
    }

    group('fromMap', () {
      test('creates PostChatMessage from valid map with Timestamp', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('messages').doc('test').set({
          'id': 'msg-123',
          'postId': 'post-123',
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
        final message = PostChatMessage.fromMap(doc.data()!);

        expect(message.id, 'msg-123');
        expect(message.postId, 'post-123');
        expect(message.senderId, 'user-123');
        expect(message.senderName, 'Test User');
        expect(message.senderPhotoUrl, 'https://example.com/photo.jpg');
        expect(message.content, 'Hello everyone');
        expect(message.type, PostChatMessageType.text);
        expect(message.readBy, ['user-123', 'user-456']);
        expect(message.isEdited, false);
      });

      test('handles all PostChatMessageType values', () async {
        final firestore = FakeFirebaseFirestore();

        for (final type in PostChatMessageType.values) {
          await firestore.collection('messages').doc(type.name).set({
            'id': type.name,
            'postId': 'post-123',
            'senderId': 'user-123',
            'senderName': 'Test',
            'content': 'Test',
            'type': type.name,
            'timestamp': Timestamp.fromDate(fixedDate),
            'readBy': [],
          });

          final doc =
              await firestore.collection('messages').doc(type.name).get();
          final message = PostChatMessage.fromMap(doc.data()!);
          expect(message.type, type);
        }
      });

      test('handles missing optional fields', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('messages').doc('test').set({
          'id': 'msg-123',
          'postId': 'post-123',
          'senderId': 'user-123',
          'senderName': 'Test',
          'content': 'Hello',
          'timestamp': Timestamp.fromDate(fixedDate),
        });

        final doc = await firestore.collection('messages').doc('test').get();
        final message = PostChatMessage.fromMap(doc.data()!);

        expect(message.senderPhotoUrl, isNull);
        expect(message.imageUrl, isNull);
        expect(message.isEdited, false);
        expect(message.editedAt, isNull);
        expect(message.type, PostChatMessageType.text);
        expect(message.readBy, isEmpty);
      });

      test('handles image message', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('messages').doc('test').set({
          'id': 'msg-123',
          'postId': 'post-123',
          'senderId': 'user-123',
          'senderName': 'Test',
          'content': 'Check this',
          'type': 'image',
          'timestamp': Timestamp.fromDate(fixedDate),
          'readBy': [],
          'imageUrl': 'https://example.com/image.jpg',
        });

        final doc = await firestore.collection('messages').doc('test').get();
        final message = PostChatMessage.fromMap(doc.data()!);

        expect(message.type, PostChatMessageType.image);
        expect(message.imageUrl, 'https://example.com/image.jpg');
      });

      test('handles edited message', () async {
        final editedAt = fixedDate.add(const Duration(minutes: 5));
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('messages').doc('test').set({
          'id': 'msg-123',
          'postId': 'post-123',
          'senderId': 'user-123',
          'senderName': 'Test',
          'content': 'Edited content',
          'timestamp': Timestamp.fromDate(fixedDate),
          'readBy': [],
          'isEdited': true,
          'editedAt': Timestamp.fromDate(editedAt),
        });

        final doc = await firestore.collection('messages').doc('test').get();
        final message = PostChatMessage.fromMap(doc.data()!);

        expect(message.isEdited, true);
        expect(message.editedAt, editedAt);
      });
    });

    group('toMap', () {
      test('converts PostChatMessage to map correctly', () {
        final message = PostChatMessage(
          id: 'msg-123',
          postId: 'post-123',
          senderId: 'user-123',
          senderName: 'Test User',
          senderPhotoUrl: 'https://example.com/photo.jpg',
          content: 'Hello',
          type: PostChatMessageType.text,
          timestamp: fixedDate,
          readBy: ['user-123'],
          isEdited: false,
        );

        final map = message.toMap();

        expect(map['id'], 'msg-123');
        expect(map['postId'], 'post-123');
        expect(map['senderId'], 'user-123');
        expect(map['senderName'], 'Test User');
        expect(map['senderPhotoUrl'], 'https://example.com/photo.jpg');
        expect(map['content'], 'Hello');
        expect(map['type'], 'text');
        expect(map['readBy'], ['user-123']);
        expect(map['isEdited'], false);
        expect(map['timestamp'], isA<Timestamp>());
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
        expect(copy.postId, original.postId);
      });

      test('can update readBy list', () {
        final original = createTestMessage(readBy: ['user-123']);
        final copy = original.copyWith(
          readBy: ['user-123', 'user-456'],
        );

        expect(copy.readBy, ['user-123', 'user-456']);
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
    });

    group('static factory methods', () {
      test('createSystemMessage creates system message', () {
        final message = PostChatMessage.createSystemMessage(
          postId: 'post-123',
          content: 'System notification',
          messageId: 'sys-msg-1',
        );

        expect(message.id, 'sys-msg-1');
        expect(message.postId, 'post-123');
        expect(message.senderId, 'system');
        expect(message.senderName, 'System');
        expect(message.content, 'System notification');
        expect(message.type, PostChatMessageType.system);
        expect(message.readBy, isEmpty);
      });

      test('userJoinedMessage creates join message', () {
        final message = PostChatMessage.userJoinedMessage(
          postId: 'post-123',
          userName: 'John',
          messageId: 'join-msg-1',
        );

        expect(message.content, 'John joined the group');
        expect(message.type, PostChatMessageType.system);
        expect(message.senderId, 'system');
      });

      test('userLeftMessage creates leave message', () {
        final message = PostChatMessage.userLeftMessage(
          postId: 'post-123',
          userName: 'John',
          messageId: 'left-msg-1',
        );

        expect(message.content, 'John left the group');
        expect(message.type, PostChatMessageType.system);
        expect(message.senderId, 'system');
      });
    });
  });
}
