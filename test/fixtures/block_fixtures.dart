import 'package:squad_app/models/block_model.dart';
import 'user_fixtures.dart';

/// Test fixtures for BlockModel
///
/// Usage:
/// ```dart
/// final block = BlockFixtures.basicBlock;
/// ```
class BlockFixtures {
  static final DateTime _fixedDate = DateTime(2024, 1, 1, 12, 0, 0);

  /// A basic block relationship
  static BlockModel get basicBlock => BlockModel(
        id: 'block-123',
        blockerId: UserFixtures.basicUser.id,
        blockedId: 'user-blocked',
        createdAt: _fixedDate,
        reason: 'Spam',
      );

  /// A block without a reason
  static BlockModel get blockWithoutReason => BlockModel(
        id: 'block-456',
        blockerId: UserFixtures.basicUser.id,
        blockedId: UserFixtures.secondUser.id,
        createdAt: _fixedDate,
      );

  /// A block where basicUser is the one blocked
  static BlockModel get reverseBlock => BlockModel(
        id: 'block-789',
        blockerId: UserFixtures.userWhoBlocked.id,
        blockedId: UserFixtures.basicUser.id,
        createdAt: _fixedDate,
        reason: 'Harassment',
      );

  /// Creates a custom block
  static BlockModel custom({
    String? id,
    String? blockerId,
    String? blockedId,
    DateTime? createdAt,
    String? reason,
  }) {
    return BlockModel(
      id: id ?? 'block-custom',
      blockerId: blockerId ?? UserFixtures.basicUser.id,
      blockedId: blockedId ?? 'user-to-block',
      createdAt: createdAt ?? _fixedDate,
      reason: reason,
    );
  }

  /// List of blocks for testing filtering
  static List<BlockModel> get multipleBlocks => [
        basicBlock,
        blockWithoutReason,
      ];
}
