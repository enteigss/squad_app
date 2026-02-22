/// Match status enum representing the lifecycle of a match
enum MatchStatus { pending, active, completed, expired, declined }

/// Extension to convert MatchStatus to/from string for Firestore
extension MatchStatusExtension on MatchStatus {
  String get value {
    switch (this) {
      case MatchStatus.pending:
        return 'pending';
      case MatchStatus.active:
        return 'active';
      case MatchStatus.completed:
        return 'completed';
      case MatchStatus.expired:
        return 'expired';
      case MatchStatus.declined:
        return 'declined';
    }
  }

  static MatchStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return MatchStatus.pending;
      case 'active':
        return MatchStatus.active;
      case 'completed':
        return MatchStatus.completed;
      case 'expired':
        return MatchStatus.expired;
      case 'declined':
        return MatchStatus.declined;
      default:
        return MatchStatus.pending;
    }
  }
}

/// Model representing a match between users
///
/// A match groups users together based on compatibility and suggests
/// activities and shared interests to help them connect.
class MatchModel {
  final String id;
  final String groupId;
  final List<String> memberIds;
  final String reasoning;
  final String potentialDownside;
  final String activitySuggestion;
  final String sharedInterests;
  final DateTime createdAt;
  final MatchStatus status;

  MatchModel({
    required this.id,
    required this.groupId,
    required this.memberIds,
    required this.reasoning,
    required this.potentialDownside,
    required this.activitySuggestion,
    required this.sharedInterests,
    required this.createdAt,
    this.status = MatchStatus.pending,
  });

  /// Create a MatchModel from a Firestore document map
  factory MatchModel.fromMap(Map<String, dynamic> map) {
    return MatchModel(
      id: map['id'] as String? ?? '',
      groupId: map['groupId'] as String? ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      reasoning: map['reasoning'] as String? ?? '',
      potentialDownside: map['potentialDownside'] as String? ?? '',
      activitySuggestion: map['activitySuggestion'] as String? ?? '',
      sharedInterests: map['sharedInterests'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      status: MatchStatusExtension.fromString(
        map['status'] as String? ?? 'pending',
      ),
    );
  }

  /// Convert the MatchModel to a map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'memberIds': memberIds,
      'reasoning': reasoning,
      'potentialDownside': potentialDownside,
      'activitySuggestion': activitySuggestion,
      'sharedInterests': sharedInterests,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'status': status.value,
    };
  }

  /// Create a copy of this MatchModel with updated fields
  MatchModel copyWith({
    String? id,
    String? groupId,
    List<String>? memberIds,
    String? reasoning,
    String? potentialDownside,
    String? activitySuggestion,
    String? sharedInterests,
    DateTime? createdAt,
    MatchStatus? status,
  }) {
    return MatchModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      memberIds: memberIds ?? this.memberIds,
      reasoning: reasoning ?? this.reasoning,
      potentialDownside: potentialDownside ?? this.potentialDownside,
      activitySuggestion: activitySuggestion ?? this.activitySuggestion,
      sharedInterests: sharedInterests ?? this.sharedInterests,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  /// Parse DateTime from various formats (Firestore Timestamp or milliseconds)
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is DateTime) {
      return value;
    }
    // Handle Firestore Timestamp
    if (value.runtimeType.toString().contains('Timestamp')) {
      return (value as dynamic).toDate();
    }
    return DateTime.now();
  }

  @override
  String toString() {
    return 'MatchModel(id: $id, groupId: $groupId, memberIds: $memberIds, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MatchModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
