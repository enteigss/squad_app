import 'package:flutter_test/flutter_test.dart';
import 'package:squad_app/models/group_model.dart';

void main() {
  group('GroupModel', () {
    final fixedDate = DateTime(2024, 1, 1, 12, 0, 0);

    GroupModel createTestGroup({
      String id = 'group-123',
      String name = 'Test Group',
      String? description = 'A test group',
      List<String> memberIds = const ['user-123', 'user-456'],
      List<String> adminIds = const ['user-123'],
      String? lastMessageId,
      DateTime? lastMessageTime,
    }) {
      return GroupModel(
        id: id,
        name: name,
        description: description,
        createdAt: fixedDate,
        memberIds: memberIds,
        adminIds: adminIds,
        lastMessageId: lastMessageId,
        lastMessageTime: lastMessageTime,
      );
    }

    group('fromMap', () {
      test('creates GroupModel from valid map', () {
        final map = {
          'id': 'group-123',
          'name': 'Test Group',
          'description': 'A test group',
          'imageUrl': 'https://example.com/group.jpg',
          'createdAt': fixedDate.millisecondsSinceEpoch,
          'memberIds': ['user-123', 'user-456'],
          'adminIds': ['user-123'],
          'lastMessageId': 'msg-999',
          'lastMessageTime': fixedDate.millisecondsSinceEpoch,
        };

        final group = GroupModel.fromMap(map);

        expect(group.id, 'group-123');
        expect(group.name, 'Test Group');
        expect(group.description, 'A test group');
        expect(group.imageUrl, 'https://example.com/group.jpg');
        expect(group.memberIds, ['user-123', 'user-456']);
        expect(group.adminIds, ['user-123']);
        expect(group.lastMessageId, 'msg-999');
      });

      test('handles missing optional fields', () {
        final map = {
          'id': 'group-123',
          'name': 'Test Group',
          'createdAt': fixedDate.millisecondsSinceEpoch,
        };

        final group = GroupModel.fromMap(map);

        expect(group.description, isNull);
        expect(group.imageUrl, isNull);
        expect(group.memberIds, isEmpty);
        expect(group.adminIds, isEmpty);
        expect(group.lastMessageId, isNull);
        expect(group.lastMessageTime, isNull);
      });

      test('handles null lists with empty defaults', () {
        final map = {
          'id': 'group-123',
          'name': 'Test Group',
          'createdAt': fixedDate.millisecondsSinceEpoch,
          'memberIds': null,
          'adminIds': null,
        };

        final group = GroupModel.fromMap(map);

        expect(group.memberIds, isEmpty);
        expect(group.adminIds, isEmpty);
      });
    });

    group('toMap', () {
      test('converts GroupModel to map correctly', () {
        final group = GroupModel(
          id: 'group-123',
          name: 'Test Group',
          description: 'A test group',
          imageUrl: 'https://example.com/group.jpg',
          createdAt: fixedDate,
          memberIds: ['user-123', 'user-456'],
          adminIds: ['user-123'],
          lastMessageId: 'msg-999',
          lastMessageTime: fixedDate,
        );

        final map = group.toMap();

        expect(map['id'], 'group-123');
        expect(map['name'], 'Test Group');
        expect(map['description'], 'A test group');
        expect(map['imageUrl'], 'https://example.com/group.jpg');
        expect(map['createdAt'], fixedDate.millisecondsSinceEpoch);
        expect(map['memberIds'], ['user-123', 'user-456']);
        expect(map['adminIds'], ['user-123']);
        expect(map['lastMessageId'], 'msg-999');
        expect(map['lastMessageTime'], fixedDate.millisecondsSinceEpoch);
      });

      test('handles null optional fields', () {
        final group = GroupModel(
          id: 'group-123',
          name: 'Test Group',
          createdAt: fixedDate,
        );

        final map = group.toMap();

        expect(map['description'], isNull);
        expect(map['imageUrl'], isNull);
        expect(map['lastMessageId'], isNull);
        expect(map['lastMessageTime'], isNull);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = createTestGroup();
        final copy = original.copyWith(
          name: 'Updated Name',
          description: 'Updated description',
        );

        expect(copy.name, 'Updated Name');
        expect(copy.description, 'Updated description');
        expect(copy.id, original.id);
        expect(copy.memberIds, original.memberIds);
      });

      test('can update member lists', () {
        final original = createTestGroup();
        final copy = original.copyWith(
          memberIds: ['user-123', 'user-456', 'user-789'],
          adminIds: ['user-123', 'user-456'],
        );

        expect(copy.memberIds, ['user-123', 'user-456', 'user-789']);
        expect(copy.adminIds, ['user-123', 'user-456']);
      });

      test('can update last message info', () {
        final original = createTestGroup();
        final newTime = fixedDate.add(const Duration(hours: 1));
        final copy = original.copyWith(
          lastMessageId: 'msg-new',
          lastMessageTime: newTime,
        );

        expect(copy.lastMessageId, 'msg-new');
        expect(copy.lastMessageTime, newTime);
      });
    });

    group('isAdmin', () {
      test('returns true for admin user', () {
        final group = createTestGroup(adminIds: ['user-123', 'user-456']);

        expect(group.isAdmin('user-123'), true);
        expect(group.isAdmin('user-456'), true);
      });

      test('returns false for non-admin user', () {
        final group = createTestGroup(adminIds: ['user-123']);

        expect(group.isAdmin('user-456'), false);
        expect(group.isAdmin('user-789'), false);
      });
    });

    group('isMember', () {
      test('returns true for member', () {
        final group = createTestGroup(memberIds: ['user-123', 'user-456']);

        expect(group.isMember('user-123'), true);
        expect(group.isMember('user-456'), true);
      });

      test('returns false for non-member', () {
        final group = createTestGroup(memberIds: ['user-123']);

        expect(group.isMember('user-456'), false);
        expect(group.isMember('user-789'), false);
      });
    });

    group('roundtrip serialization', () {
      test('toMap then fromMap produces equivalent object', () {
        final original = GroupModel(
          id: 'group-123',
          name: 'Test Group',
          description: 'A test group',
          imageUrl: 'https://example.com/group.jpg',
          createdAt: fixedDate,
          memberIds: ['user-123', 'user-456'],
          adminIds: ['user-123'],
          lastMessageId: 'msg-999',
          lastMessageTime: fixedDate,
        );

        final map = original.toMap();
        final restored = GroupModel.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.description, original.description);
        expect(restored.imageUrl, original.imageUrl);
        expect(restored.memberIds, original.memberIds);
        expect(restored.adminIds, original.adminIds);
        expect(restored.lastMessageId, original.lastMessageId);
      });
    });
  });
}
