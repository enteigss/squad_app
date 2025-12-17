import 'package:flutter_test/flutter_test.dart';
import 'package:squad_app/models/block_model.dart';

void main() {
  group('BlockModel', () {
    final fixedDate = DateTime(2024, 1, 1, 12, 0, 0);

    group('fromMap', () {
      test('creates BlockModel from valid map', () {
        final map = {
          'id': 'block-123',
          'blockerId': 'user-123',
          'blockedId': 'user-456',
          'createdAt': fixedDate.millisecondsSinceEpoch,
          'reason': 'Spam',
        };

        final block = BlockModel.fromMap(map);

        expect(block.id, 'block-123');
        expect(block.blockerId, 'user-123');
        expect(block.blockedId, 'user-456');
        expect(block.reason, 'Spam');
      });

      test('handles missing reason', () {
        final map = {
          'id': 'block-123',
          'blockerId': 'user-123',
          'blockedId': 'user-456',
          'createdAt': fixedDate.millisecondsSinceEpoch,
        };

        final block = BlockModel.fromMap(map);

        expect(block.reason, isNull);
      });

      test('handles null id fields with empty string', () {
        final map = {
          'id': null,
          'blockerId': null,
          'blockedId': null,
          'createdAt': fixedDate.millisecondsSinceEpoch,
        };

        final block = BlockModel.fromMap(map);

        expect(block.id, '');
        expect(block.blockerId, '');
        expect(block.blockedId, '');
      });

      test('handles DateTime object in createdAt', () {
        final map = {
          'id': 'block-123',
          'blockerId': 'user-123',
          'blockedId': 'user-456',
          'createdAt': fixedDate,
        };

        final block = BlockModel.fromMap(map);

        expect(block.createdAt, fixedDate);
      });

      test('handles null createdAt with current time', () {
        final map = {
          'id': 'block-123',
          'blockerId': 'user-123',
          'blockedId': 'user-456',
          'createdAt': null,
        };

        final before = DateTime.now();
        final block = BlockModel.fromMap(map);
        final after = DateTime.now();

        expect(block.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), true);
        expect(block.createdAt.isBefore(after.add(const Duration(seconds: 1))), true);
      });
    });

    group('toMap', () {
      test('converts BlockModel to map correctly', () {
        final block = BlockModel(
          id: 'block-123',
          blockerId: 'user-123',
          blockedId: 'user-456',
          createdAt: fixedDate,
          reason: 'Harassment',
        );

        final map = block.toMap();

        expect(map['id'], 'block-123');
        expect(map['blockerId'], 'user-123');
        expect(map['blockedId'], 'user-456');
        expect(map['createdAt'], fixedDate.millisecondsSinceEpoch);
        expect(map['reason'], 'Harassment');
      });

      test('handles null reason', () {
        final block = BlockModel(
          id: 'block-123',
          blockerId: 'user-123',
          blockedId: 'user-456',
          createdAt: fixedDate,
        );

        final map = block.toMap();

        expect(map['reason'], isNull);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = BlockModel(
          id: 'block-123',
          blockerId: 'user-123',
          blockedId: 'user-456',
          createdAt: fixedDate,
          reason: 'Original reason',
        );

        final copy = original.copyWith(reason: 'Updated reason');

        expect(copy.reason, 'Updated reason');
        expect(copy.id, original.id);
        expect(copy.blockerId, original.blockerId);
        expect(copy.blockedId, original.blockedId);
      });

      test('returns equivalent copy when no arguments provided', () {
        final original = BlockModel(
          id: 'block-123',
          blockerId: 'user-123',
          blockedId: 'user-456',
          createdAt: fixedDate,
          reason: 'Spam',
        );

        final copy = original.copyWith();

        expect(copy, original);
      });
    });

    group('equality', () {
      test('two BlockModels with same values are equal', () {
        final block1 = BlockModel(
          id: 'block-123',
          blockerId: 'user-123',
          blockedId: 'user-456',
          createdAt: fixedDate,
          reason: 'Spam',
        );

        final block2 = BlockModel(
          id: 'block-123',
          blockerId: 'user-123',
          blockedId: 'user-456',
          createdAt: fixedDate,
          reason: 'Spam',
        );

        expect(block1, block2);
        expect(block1.hashCode, block2.hashCode);
      });

      test('two BlockModels with different values are not equal', () {
        final block1 = BlockModel(
          id: 'block-123',
          blockerId: 'user-123',
          blockedId: 'user-456',
          createdAt: fixedDate,
        );

        final block2 = BlockModel(
          id: 'block-456',
          blockerId: 'user-123',
          blockedId: 'user-456',
          createdAt: fixedDate,
        );

        expect(block1, isNot(block2));
      });

      test('BlockModel is not equal to different type', () {
        final block = BlockModel(
          id: 'block-123',
          blockerId: 'user-123',
          blockedId: 'user-456',
          createdAt: fixedDate,
        );

        expect(block == 'not a block', false);
      });
    });

    group('toString', () {
      test('returns readable string representation', () {
        final block = BlockModel(
          id: 'block-123',
          blockerId: 'user-123',
          blockedId: 'user-456',
          createdAt: fixedDate,
          reason: 'Spam',
        );

        final str = block.toString();

        expect(str, contains('block-123'));
        expect(str, contains('user-123'));
        expect(str, contains('user-456'));
        expect(str, contains('Spam'));
      });
    });

    group('roundtrip serialization', () {
      test('toMap then fromMap produces equal object', () {
        final original = BlockModel(
          id: 'block-123',
          blockerId: 'user-123',
          blockedId: 'user-456',
          createdAt: fixedDate,
          reason: 'Harassment',
        );

        final map = original.toMap();
        final restored = BlockModel.fromMap(map);

        expect(restored, original);
      });
    });
  });
}
