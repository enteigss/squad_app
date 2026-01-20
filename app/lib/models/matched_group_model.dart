import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a matched group
enum MatchedGroupStatus {
  active,
  archived,
}

/// Extension for MatchedGroupStatus serialization
extension MatchedGroupStatusExtension on MatchedGroupStatus {
  String get value => name;

  static MatchedGroupStatus fromString(String value) {
    return MatchedGroupStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => MatchedGroupStatus.active,
    );
  }
}

/// Model for groups created from the matching algorithm
///
/// A matched group is created when users are matched together based on
/// compatibility. Unlike hangout posts which are event-based, matched
/// groups are for ongoing friendship/connection.
class MatchedGroupModel {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final List<String> memberIds;
  final String? matchId; // Reference to the MatchModel that created this group
  final DateTime createdAt;
  final MatchedGroupStatus status;
  final DateTime? archivedAt;

  // Chat metadata (cached on group document for list displays)
  final String? lastMessageId;
  final DateTime? lastMessageTime;
  final String? lastMessagePreview;

  // Suggestions from the match algorithm
  final String? activitySuggestion;
  final String? conversationStarter;

  MatchedGroupModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.memberIds,
    this.matchId,
    required this.createdAt,
    this.status = MatchedGroupStatus.active,
    this.archivedAt,
    this.lastMessageId,
    this.lastMessageTime,
    this.lastMessagePreview,
    this.activitySuggestion,
    this.conversationStarter,
  });

  factory MatchedGroupModel.fromMap(Map<String, dynamic> map) {
    return MatchedGroupModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      imageUrl: map['imageUrl'],
      memberIds: List<String>.from(map['memberIds'] ?? []),
      matchId: map['matchId'],
      createdAt: _parseTimestamp(map['createdAt']),
      status: MatchedGroupStatusExtension.fromString(map['status'] ?? 'active'),
      archivedAt: map['archivedAt'] != null ? _parseTimestamp(map['archivedAt']) : null,
      lastMessageId: map['lastMessageId'],
      lastMessageTime:
          map['lastMessageTime'] != null ? _parseTimestamp(map['lastMessageTime']) : null,
      lastMessagePreview: map['lastMessagePreview'],
      activitySuggestion: map['activitySuggestion'],
      conversationStarter: map['conversationStarter'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'memberIds': memberIds,
      'matchId': matchId,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.value,
      'archivedAt': archivedAt != null ? Timestamp.fromDate(archivedAt!) : null,
      'lastMessageId': lastMessageId,
      'lastMessageTime':
          lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
      'lastMessagePreview': lastMessagePreview,
      'activitySuggestion': activitySuggestion,
      'conversationStarter': conversationStarter,
    };
  }

  MatchedGroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    List<String>? memberIds,
    String? matchId,
    DateTime? createdAt,
    MatchedGroupStatus? status,
    DateTime? archivedAt,
    String? lastMessageId,
    DateTime? lastMessageTime,
    String? lastMessagePreview,
    String? activitySuggestion,
    String? conversationStarter,
  }) {
    return MatchedGroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      memberIds: memberIds ?? this.memberIds,
      matchId: matchId ?? this.matchId,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      archivedAt: archivedAt ?? this.archivedAt,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      activitySuggestion: activitySuggestion ?? this.activitySuggestion,
      conversationStarter: conversationStarter ?? this.conversationStarter,
    );
  }

  // Helper methods
  bool isMember(String userId) => memberIds.contains(userId);

  bool get isArchived => status == MatchedGroupStatus.archived;

  int get memberCount => memberIds.length;

  /// Parse timestamp from various formats
  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is DateTime) {
      return value;
    }
    if (value.runtimeType.toString().contains('Timestamp')) {
      return (value as dynamic).toDate();
    }
    return DateTime.now();
  }

  /// Create a new matched group from a match
  factory MatchedGroupModel.fromMatch({
    required String id,
    required String matchId,
    required List<String> memberIds,
    required String activitySuggestion,
    required String conversationStarter,
    String? name,
  }) {
    return MatchedGroupModel(
      id: id,
      name: name ?? 'New Match',
      memberIds: memberIds,
      matchId: matchId,
      createdAt: DateTime.now(),
      activitySuggestion: activitySuggestion,
      conversationStarter: conversationStarter,
    );
  }

  @override
  String toString() {
    return 'MatchedGroupModel(id: $id, name: $name, memberIds: $memberIds, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MatchedGroupModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
