import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_app/models/chat_message.dart';
import 'package:squad_app/models/post_model.dart';
import 'package:squad_app/models/matched_group_model.dart';
import 'package:squad_app/services/chat_service.dart';

void main() {
  group('ChatService', () {
    late ChatService chatService;
    late FakeFirebaseFirestore fakeFirestore;

    const postId = 'post-123';
    const groupId = 'group-123';
    const userId = 'user-123';
    const userName = 'Test User';
    const otherUserId = 'user-456';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      chatService = ChatService(firestore: fakeFirestore);
    });

    // ── Helpers ──────────────────────────────────────────────────────────

    Future<void> seedHangoutPost({
      String id = postId,
      List<String>? participantIds,
      PostStatus status = PostStatus.ongoing,
    }) async {
      final post = Post(
        id: id,
        type: PostType.waving,
        activity: Activity.chilling,
        description: 'Test hangout',
        authorId: userId,
        authorName: userName,
        createdAt: DateTime(2024, 1, 1),
        status: status,
        participantIds: participantIds ?? [userId, otherUserId],
      );
      await fakeFirestore.collection('posts').doc(id).set(post.toMap());
    }

    Future<void> seedMatchedGroup({
      String id = groupId,
      List<String>? memberIds,
      MatchedGroupStatus status = MatchedGroupStatus.active,
    }) async {
      final group = MatchedGroupModel(
        id: id,
        name: 'Test Group',
        memberIds: memberIds ?? [userId, otherUserId],
        createdAt: DateTime(2024, 1, 1),
        status: status,
      );
      await fakeFirestore
          .collection('matched_groups')
          .doc(id)
          .set(group.toMap());
    }

    /// Seeds a message directly into Firestore and returns its doc ID.
    Future<String> seedMessage({
      ChatContext context = ChatContext.hangout,
      String? chatRoomId,
      String? senderId,
      String? senderName,
      String content = 'Test message',
      ChatMessageType type = ChatMessageType.text,
      List<String>? readBy,
      DateTime? timestamp,
    }) async {
      final roomId = chatRoomId ??
          (context == ChatContext.hangout ? postId : groupId);
      final collection = context == ChatContext.hangout
          ? fakeFirestore
              .collection('posts')
              .doc(roomId)
              .collection('chat')
          : fakeFirestore
              .collection('matched_groups')
              .doc(roomId)
              .collection('messages');

      final docRef = collection.doc();
      final sid = senderId ?? userId;
      final message = ChatMessage(
        id: docRef.id,
        chatRoomId: roomId,
        context: context,
        senderId: sid,
        senderName: senderName ?? userName,
        content: content,
        type: type,
        timestamp: timestamp ?? DateTime.now(),
        readBy: readBy ?? [sid],
      );
      await docRef.set(message.toMap());
      return docRef.id;
    }

    // ── sendMessage ─────────────────────────────────────────────────────

    group('sendMessage', () {
      test('creates message in hangout chat collection', () async {
        await seedHangoutPost();

        final result = await chatService.sendMessage(
          context: ChatContext.hangout,
          chatRoomId: postId,
          senderId: userId,
          senderName: userName,
          content: 'Hello everyone!',
        );

        // Verify message exists in posts/{postId}/chat
        final msgDoc = await fakeFirestore
            .collection('posts')
            .doc(postId)
            .collection('chat')
            .doc(result.id)
            .get();
        expect(msgDoc.exists, true);
        expect(msgDoc.data()?['content'], 'Hello everyone!');
        expect(msgDoc.data()?['senderId'], userId);
        expect(msgDoc.data()?['type'], 'text');
      });

      test('creates message in matched group messages collection', () async {
        await seedMatchedGroup();

        final result = await chatService.sendMessage(
          context: ChatContext.matchedGroup,
          chatRoomId: groupId,
          senderId: userId,
          senderName: userName,
          content: 'Hey squad!',
        );

        // Verify message exists in matched_groups/{groupId}/messages
        final msgDoc = await fakeFirestore
            .collection('matched_groups')
            .doc(groupId)
            .collection('messages')
            .doc(result.id)
            .get();
        expect(msgDoc.exists, true);
        expect(msgDoc.data()?['content'], 'Hey squad!');
      });

      test('updates parent doc with chat activity metadata', () async {
        await seedHangoutPost();

        final result = await chatService.sendMessage(
          context: ChatContext.hangout,
          chatRoomId: postId,
          senderId: userId,
          senderName: userName,
          content: 'Activity test',
        );

        final postDoc =
            await fakeFirestore.collection('posts').doc(postId).get();
        expect(postDoc.data()?['lastChatMessageId'], result.id);
        expect(postDoc.data()?['lastChatActivity'], isNotNull);
      });

      test('includes sender in readBy list', () async {
        await seedHangoutPost();

        final result = await chatService.sendMessage(
          context: ChatContext.hangout,
          chatRoomId: postId,
          senderId: userId,
          senderName: userName,
          content: 'Read by me',
        );

        expect(result.readBy, contains(userId));
      });
    });

    // ── sendSystemMessage ───────────────────────────────────────────────

    group('sendSystemMessage', () {
      test('creates system-type message with system sender', () async {
        await seedHangoutPost();

        final result = await chatService.sendSystemMessage(
          context: ChatContext.hangout,
          chatRoomId: postId,
          content: 'System notification',
        );

        expect(result.senderId, 'system');
        expect(result.senderName, 'System');
        expect(result.type, ChatMessageType.system);
        expect(result.content, 'System notification');

        // Verify persisted in Firestore
        final msgDoc = await fakeFirestore
            .collection('posts')
            .doc(postId)
            .collection('chat')
            .doc(result.id)
            .get();
        expect(msgDoc.exists, true);
        expect(msgDoc.data()?['type'], 'system');
      });

      test('updates parent doc chat activity', () async {
        await seedHangoutPost();

        await chatService.sendSystemMessage(
          context: ChatContext.hangout,
          chatRoomId: postId,
          content: 'System msg',
        );

        final postDoc =
            await fakeFirestore.collection('posts').doc(postId).get();
        expect(postDoc.data()?['lastChatActivity'], isNotNull);
      });
    });

    // ── getMessages ─────────────────────────────────────────────────────

    group('getMessages', () {
      test('returns stream of messages', () async {
        // Seed two messages with different timestamps
        await seedMessage(
          content: 'First',
          timestamp: DateTime(2024, 1, 1, 10, 0),
        );
        await seedMessage(
          content: 'Second',
          timestamp: DateTime(2024, 1, 1, 11, 0),
        );

        final stream =
            chatService.getMessages(ChatContext.hangout, postId);
        final messages = await stream.first;

        expect(messages.length, 2);
        // Ordered descending by timestamp — newest first
        expect(messages.first.content, 'Second');
        expect(messages.last.content, 'First');
      });

      test('emits empty list for chat with no messages', () async {
        final stream =
            chatService.getMessages(ChatContext.hangout, postId);
        final messages = await stream.first;

        expect(messages, isEmpty);
      });
    });

    // ── markMessagesAsRead ──────────────────────────────────────────────

    group('markMessagesAsRead', () {
      test('adds userId to readBy for unread messages', () async {
        // Seed a message from otherUser that current user hasn't read
        final msgId = await seedMessage(
          senderId: otherUserId,
          senderName: 'Other User',
          readBy: [otherUserId], // Only sender has read it
        );

        await chatService.markMessagesAsRead(
          ChatContext.hangout,
          postId,
          userId,
        );

        final msgDoc = await fakeFirestore
            .collection('posts')
            .doc(postId)
            .collection('chat')
            .doc(msgId)
            .get();
        expect(
          List<String>.from(msgDoc.data()?['readBy'] ?? []),
          contains(userId),
        );
      });

      test('does not duplicate userId if already in readBy', () async {
        // Seed a message that current user has already read
        final msgId = await seedMessage(
          senderId: otherUserId,
          senderName: 'Other User',
          readBy: [otherUserId, userId], // Already read by userId
        );

        await chatService.markMessagesAsRead(
          ChatContext.hangout,
          postId,
          userId,
        );

        final msgDoc = await fakeFirestore
            .collection('posts')
            .doc(postId)
            .collection('chat')
            .doc(msgId)
            .get();
        final readBy = List<String>.from(msgDoc.data()?['readBy'] ?? []);
        // userId should appear exactly once
        expect(readBy.where((id) => id == userId).length, 1);
      });
    });

    // ── getUnreadCount ──────────────────────────────────────────────────

    group('getUnreadCount', () {
      test('counts messages not read by user excluding own', () async {
        // Message from other user, not read by current user
        await seedMessage(
          senderId: otherUserId,
          senderName: 'Other User',
          readBy: [otherUserId],
        );
        // Message from current user (should not count)
        await seedMessage(
          senderId: userId,
          readBy: [userId],
        );

        final count = await chatService.getUnreadCount(
          ChatContext.hangout,
          postId,
          userId,
        );

        expect(count, 1);
      });

      test('returns 0 when only own messages exist', () async {
        // Only messages from current user — should never count as unread
        await seedMessage(
          senderId: userId,
          readBy: [userId],
        );

        final count = await chatService.getUnreadCount(
          ChatContext.hangout,
          postId,
          userId,
        );

        expect(count, 0);
      });
    });

    // ── editMessage ─────────────────────────────────────────────────────

    group('editMessage', () {
      test('updates content and sets isEdited for sender', () async {
        final msgId = await seedMessage(content: 'Original');

        await chatService.editMessage(
          context: ChatContext.hangout,
          chatRoomId: postId,
          messageId: msgId,
          newContent: 'Edited',
          userId: userId,
        );

        final msgDoc = await fakeFirestore
            .collection('posts')
            .doc(postId)
            .collection('chat')
            .doc(msgId)
            .get();
        expect(msgDoc.data()?['content'], 'Edited');
        expect(msgDoc.data()?['isEdited'], true);
        expect(msgDoc.data()?['editedAt'], isNotNull);
      });

      test('throws when non-sender tries to edit', () async {
        final msgId = await seedMessage(senderId: otherUserId);

        await expectLater(
          () => chatService.editMessage(
            context: ChatContext.hangout,
            chatRoomId: postId,
            messageId: msgId,
            newContent: 'Hacked',
            userId: userId,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('edit your own messages'),
            ),
          ),
        );
      });

      test('throws when message does not exist', () async {
        await expectLater(
          () => chatService.editMessage(
            context: ChatContext.hangout,
            chatRoomId: postId,
            messageId: 'nonexistent',
            newContent: 'Nope',
            userId: userId,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Message not found'),
            ),
          ),
        );
      });
    });

    // ── deleteMessage ───────────────────────────────────────────────────

    group('deleteMessage', () {
      test('removes message document for sender', () async {
        final msgId = await seedMessage();

        await chatService.deleteMessage(
          context: ChatContext.hangout,
          chatRoomId: postId,
          messageId: msgId,
          userId: userId,
        );

        final msgDoc = await fakeFirestore
            .collection('posts')
            .doc(postId)
            .collection('chat')
            .doc(msgId)
            .get();
        expect(msgDoc.exists, false);
      });

      test('throws when non-sender tries to delete', () async {
        final msgId = await seedMessage(senderId: otherUserId);

        await expectLater(
          () => chatService.deleteMessage(
            context: ChatContext.hangout,
            chatRoomId: postId,
            messageId: msgId,
            userId: userId,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('delete your own messages'),
            ),
          ),
        );
      });

      test('throws when message does not exist', () async {
        await expectLater(
          () => chatService.deleteMessage(
            context: ChatContext.hangout,
            chatRoomId: postId,
            messageId: 'nonexistent',
            userId: userId,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Message not found'),
            ),
          ),
        );
      });
    });

    // ── initializeChat ──────────────────────────────────────────────────

    group('initializeChat', () {
      test('sends hangout welcome message when chat is empty', () async {
        await seedHangoutPost();

        await chatService.initializeChat(ChatContext.hangout, postId);

        final msgs = await fakeFirestore
            .collection('posts')
            .doc(postId)
            .collection('chat')
            .get();
        expect(msgs.docs.length, 1);
        expect(
          msgs.docs.first.data()['content'],
          contains('Welcome to the group chat'),
        );
        expect(msgs.docs.first.data()['type'], 'system');
      });

      test('sends matched group welcome message when chat is empty',
          () async {
        await seedMatchedGroup();

        await chatService.initializeChat(
            ChatContext.matchedGroup, groupId);

        final msgs = await fakeFirestore
            .collection('matched_groups')
            .doc(groupId)
            .collection('messages')
            .get();
        expect(msgs.docs.length, 1);
        expect(
          msgs.docs.first.data()['content'],
          contains("You've been matched"),
        );
      });

      test('does not send welcome when chat already has messages', () async {
        await seedHangoutPost();
        await seedMessage(content: 'Existing message');

        await chatService.initializeChat(ChatContext.hangout, postId);

        final msgs = await fakeFirestore
            .collection('posts')
            .doc(postId)
            .collection('chat')
            .get();
        // Should still only have the original message
        expect(msgs.docs.length, 1);
        expect(msgs.docs.first.data()['content'], 'Existing message');
      });
    });

    // ── initializeMatchedGroupChat ──────────────────────────────────────

    group('initializeMatchedGroupChat', () {
      test('sends match created message with shared interests', () async {
        await seedMatchedGroup();

        await chatService.initializeMatchedGroupChat(
          groupId,
          'music, hiking',
        );

        final msgs = await fakeFirestore
            .collection('matched_groups')
            .doc(groupId)
            .collection('messages')
            .get();
        expect(msgs.docs.length, 1);
        expect(
          msgs.docs.first.data()['content'],
          contains('music, hiking'),
        );
      });

      test('skips if messages already exist', () async {
        await seedMatchedGroup();
        await seedMessage(
          context: ChatContext.matchedGroup,
          content: 'Already here',
        );

        await chatService.initializeMatchedGroupChat(
          groupId,
          'sports',
        );

        final msgs = await fakeFirestore
            .collection('matched_groups')
            .doc(groupId)
            .collection('messages')
            .get();
        expect(msgs.docs.length, 1);
        expect(msgs.docs.first.data()['content'], 'Already here');
      });
    });

    // ── handleUserJoined ────────────────────────────────────────────────

    group('handleUserJoined', () {
      test('sends system message with user name', () async {
        await seedHangoutPost();

        await chatService.handleUserJoined(
          context: ChatContext.hangout,
          chatRoomId: postId,
          userName: 'Alice',
        );

        final msgs = await fakeFirestore
            .collection('posts')
            .doc(postId)
            .collection('chat')
            .get();
        expect(msgs.docs.length, 1);
        expect(msgs.docs.first.data()['content'], 'Alice joined the group');
        expect(msgs.docs.first.data()['type'], 'system');
      });
    });

    // ── handleUserLeft ──────────────────────────────────────────────────

    group('handleUserLeft', () {
      test('sends system message with user name', () async {
        await seedHangoutPost();

        await chatService.handleUserLeft(
          context: ChatContext.hangout,
          chatRoomId: postId,
          userName: 'Bob',
        );

        final msgs = await fakeFirestore
            .collection('posts')
            .doc(postId)
            .collection('chat')
            .get();
        expect(msgs.docs.length, 1);
        expect(msgs.docs.first.data()['content'], 'Bob left the group');
        expect(msgs.docs.first.data()['type'], 'system');
      });
    });

    // ── archiveChat ─────────────────────────────────────────────────────

    group('archiveChat', () {
      test('sends hangout archive message', () async {
        await seedHangoutPost();

        await chatService.archiveChat(ChatContext.hangout, postId);

        final msgs = await fakeFirestore
            .collection('posts')
            .doc(postId)
            .collection('chat')
            .get();
        expect(msgs.docs.length, 1);
        expect(
          msgs.docs.first.data()['content'],
          contains('This event has ended'),
        );
      });

      test('sends matched group archive message', () async {
        await seedMatchedGroup();

        await chatService.archiveChat(ChatContext.matchedGroup, groupId);

        final msgs = await fakeFirestore
            .collection('matched_groups')
            .doc(groupId)
            .collection('messages')
            .get();
        expect(msgs.docs.length, 1);
        expect(
          msgs.docs.first.data()['content'],
          contains('This group has been archived'),
        );
      });
    });

    // ── canAccessChat ───────────────────────────────────────────────────

    group('canAccessChat', () {
      test('returns true when user is in post participantIds', () async {
        await seedHangoutPost(participantIds: [userId, otherUserId]);

        expect(
          await chatService.canAccessChat(
              ChatContext.hangout, postId, userId),
          true,
        );
      });

      test('returns true when user is in group memberIds', () async {
        await seedMatchedGroup(memberIds: [userId, otherUserId]);

        expect(
          await chatService.canAccessChat(
              ChatContext.matchedGroup, groupId, userId),
          true,
        );
      });

      test('returns false when user is not a participant', () async {
        await seedHangoutPost(participantIds: [otherUserId]);

        expect(
          await chatService.canAccessChat(
              ChatContext.hangout, postId, userId),
          false,
        );
      });
    });

    // ── isChatReadOnly ──────────────────────────────────────────────────

    group('isChatReadOnly', () {
      test('returns true when post status is completed', () async {
        await seedHangoutPost(status: PostStatus.completed);

        expect(
          await chatService.isChatReadOnly(ChatContext.hangout, postId),
          true,
        );
      });

      test('returns true when group is archived', () async {
        await seedMatchedGroup(status: MatchedGroupStatus.archived);

        expect(
          await chatService.isChatReadOnly(
              ChatContext.matchedGroup, groupId),
          true,
        );
      });

      test('returns false when post is ongoing', () async {
        await seedHangoutPost(status: PostStatus.ongoing);

        expect(
          await chatService.isChatReadOnly(ChatContext.hangout, postId),
          false,
        );
      });
    });
  });
}
