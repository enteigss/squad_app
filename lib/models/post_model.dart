import 'package:cloud_firestore/cloud_firestore.dart';

enum PostStatus { upcoming, ongoing, completed }

class Post {
  final String id;
  final String title;
  final String description;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final DateTime? scheduledTime;
  final PostStatus status;
  final List<String> participantIds;
  final String? location;
  final int maxParticipants;
  final List<String> genderPreferences;
  final bool deleted;
  final String? lastChatMessageId;
  final DateTime? lastChatActivity;
  final int unreadChatCount;

  Post({
    required this.id,
    required this.title,
    required this.description,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.scheduledTime,
    required this.status,
    required this.participantIds,
    this.location,
    this.maxParticipants = 10,
    this.genderPreferences = const ['Anyone'],
    this.deleted = false,
    this.lastChatMessageId,
    this.lastChatActivity,
    this.unreadChatCount = 0,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      scheduledTime: map['scheduledTime'] != null
          ? (map['scheduledTime'] as Timestamp).toDate()
          : null,
      status: PostStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => PostStatus.upcoming,
      ),
      participantIds: List<String>.from(map['participantIds'] ?? []),
      location: map['location'],
      maxParticipants: map['maxParticipants'] ?? 10,
      genderPreferences: List<String>.from(map['genderPreferences'] ?? ['Anyone']),
      deleted: map['deleted'] ?? false,
      lastChatMessageId: map['lastChatMessageId'],
      lastChatActivity: map['lastChatActivity'] != null
          ? (map['lastChatActivity'] as Timestamp).toDate()
          : null,
      unreadChatCount: map['unreadChatCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'scheduledTime': scheduledTime != null
          ? Timestamp.fromDate(scheduledTime!)
          : null,
      'status': status.name,
      'participantIds': participantIds,
      'location': location,
      'maxParticipants': maxParticipants,
      'genderPreferences': genderPreferences,
      'deleted': deleted,
      'lastChatMessageId': lastChatMessageId,
      'lastChatActivity': lastChatActivity != null
          ? Timestamp.fromDate(lastChatActivity!)
          : null,
      'unreadChatCount': unreadChatCount,
    };
  }

  Post copyWith({
    String? id,
    String? title,
    String? description,
    String? authorId,
    String? authorName,
    DateTime? createdAt,
    DateTime? scheduledTime,
    PostStatus? status,
    List<String>? participantIds,
    String? location,
    int? maxParticipants,
    List<String>? genderPreferences,
    bool? deleted,
    String? lastChatMessageId,
    DateTime? lastChatActivity,
    int? unreadChatCount,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      createdAt: createdAt ?? this.createdAt,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
      participantIds: participantIds ?? this.participantIds,
      location: location ?? this.location,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      genderPreferences: genderPreferences ?? this.genderPreferences,
      deleted: deleted ?? this.deleted,
      lastChatMessageId: lastChatMessageId ?? this.lastChatMessageId,
      lastChatActivity: lastChatActivity ?? this.lastChatActivity,
      unreadChatCount: unreadChatCount ?? this.unreadChatCount,
    );
  }

  PostStatus get dynamicStatus {
    if (scheduledTime == null) return status;

    final now = DateTime.now();
    final timeDifference = scheduledTime!.difference(now);

    // If scheduled time is in the future, it's upcoming
    if (timeDifference.inMinutes > 0) {
      return PostStatus.upcoming;
    }

    // If scheduled time was within the last 4 hours, consider it ongoing
    // This assumes most activities last up to 4 hours
    if (timeDifference.inMinutes >= -240) {
      // -240 minutes = -4 hours
      return PostStatus.ongoing;
    }

    // If more than 4 hours have passed since scheduled time, it's completed
    return PostStatus.completed;
  }
}
