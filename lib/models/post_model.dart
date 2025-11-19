import 'package:cloud_firestore/cloud_firestore.dart';

enum PostStatus { upcoming, ongoing, completed }

enum PostType { walking, raising, waving }

enum Activity { diningHall, studying, walking, fitRec, chilling, other }

class Post {
  final String id;
  final PostType type;
  final Activity? activity;
  final String? customActivity;
  final String? description;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final DateTime? scheduledTime;
  final PostStatus status;
  final List<String> participantIds;
  final String? location;
  final String? locationTo;
  final int? maxParticipants;
  final List<String> genderPreferences;
  final bool deleted;
  final bool isLocked;
  final String? lastChatMessageId;
  final DateTime? lastChatActivity;
  final int unreadChatCount;
  final bool feedbackCollected;

  Post({
    required this.id,
    required this.type,
    this.activity,
    this.customActivity,
    this.description,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.scheduledTime,
    required this.status,
    required this.participantIds,
    this.location,
    this.locationTo,
    this.maxParticipants,
    this.genderPreferences = const ['Anyone'],
    this.deleted = false,
    this.isLocked = false,
    this.lastChatMessageId,
    this.lastChatActivity,
    this.unreadChatCount = 0,
    this.feedbackCollected = false,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'] ?? '',
      type: PostType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => PostType.waving,
      ),
      activity: map['activity'] != null
          ? Activity.values.firstWhere(
              (activity) => activity.name == map['activity'],
              orElse: () => Activity.other,
            )
          : null,
      customActivity: map['customActivity'],
      description: map['description'],
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
      locationTo: map['locationTo'],
      maxParticipants: map['maxParticipants'],
      genderPreferences: List<String>.from(map['genderPreferences'] ?? ['Anyone']),
      deleted: map['deleted'] ?? false,
      isLocked: map['isLocked'] ?? false,
      lastChatMessageId: map['lastChatMessageId'],
      lastChatActivity: map['lastChatActivity'] != null
          ? (map['lastChatActivity'] as Timestamp).toDate()
          : null,
      unreadChatCount: map['unreadChatCount'] ?? 0,
      feedbackCollected: map['feedbackCollected'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'activity': activity?.name,
      'customActivity': customActivity,
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
      'locationTo': locationTo,
      'maxParticipants': maxParticipants,
      'genderPreferences': genderPreferences,
      'deleted': deleted,
      'isLocked': isLocked,
      'lastChatMessageId': lastChatMessageId,
      'lastChatActivity': lastChatActivity != null
          ? Timestamp.fromDate(lastChatActivity!)
          : null,
      'unreadChatCount': unreadChatCount,
      'feedbackCollected': feedbackCollected,
    };
  }

  Post copyWith({
    String? id,
    PostType? type,
    Activity? activity,
    String? customActivity,
    String? description,
    String? authorId,
    String? authorName,
    DateTime? createdAt,
    DateTime? scheduledTime,
    PostStatus? status,
    List<String>? participantIds,
    String? location,
    String? locationTo,
    int? maxParticipants,
    List<String>? genderPreferences,
    bool? deleted,
    bool? isLocked,
    String? lastChatMessageId,
    DateTime? lastChatActivity,
    int? unreadChatCount,
    bool? feedbackCollected,
  }) {
    return Post(
      id: id ?? this.id,
      type: type ?? this.type,
      activity: activity ?? this.activity,
      customActivity: customActivity ?? this.customActivity,
      description: description ?? this.description,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      createdAt: createdAt ?? this.createdAt,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
      participantIds: participantIds ?? this.participantIds,
      location: location ?? this.location,
      locationTo: locationTo ?? this.locationTo,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      genderPreferences: genderPreferences ?? this.genderPreferences,
      deleted: deleted ?? this.deleted,
      isLocked: isLocked ?? this.isLocked,
      lastChatMessageId: lastChatMessageId ?? this.lastChatMessageId,
      lastChatActivity: lastChatActivity ?? this.lastChatActivity,
      unreadChatCount: unreadChatCount ?? this.unreadChatCount,
      feedbackCollected: feedbackCollected ?? this.feedbackCollected,
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
