class BlockModel {
  final String id;
  final String blockerId;
  final String blockedId;
  final DateTime createdAt;
  final String? reason;

  BlockModel({
    required this.id,
    required this.blockerId,
    required this.blockedId,
    required this.createdAt,
    this.reason,
  });

  factory BlockModel.fromMap(Map<String, dynamic> map) {
    return BlockModel(
      id: map['id'] ?? '',
      blockerId: map['blockerId'] ?? '',
      blockedId: map['blockedId'] ?? '',
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      reason: map['reason'],
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value.runtimeType.toString() == 'Timestamp') {
      return (value as dynamic).toDate();
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'blockerId': blockerId,
      'blockedId': blockedId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'reason': reason,
    };
  }

  BlockModel copyWith({
    String? id,
    String? blockerId,
    String? blockedId,
    DateTime? createdAt,
    String? reason,
  }) {
    return BlockModel(
      id: id ?? this.id,
      blockerId: blockerId ?? this.blockerId,
      blockedId: blockedId ?? this.blockedId,
      createdAt: createdAt ?? this.createdAt,
      reason: reason ?? this.reason,
    );
  }

  @override
  String toString() {
    return 'BlockModel(id: $id, blockerId: $blockerId, blockedId: $blockedId, createdAt: $createdAt, reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BlockModel &&
        other.id == id &&
        other.blockerId == blockerId &&
        other.blockedId == blockedId &&
        other.createdAt == createdAt &&
        other.reason == reason;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        blockerId.hashCode ^
        blockedId.hashCode ^
        createdAt.hashCode ^
        reason.hashCode;
  }
}