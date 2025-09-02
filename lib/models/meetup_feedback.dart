import 'package:cloud_firestore/cloud_firestore.dart';

class MeetupFeedback {
  final String id;
  final String hangoutId;
  final String userId;
  final String hangoutTitle;
  final bool didMeetup;
  final String? additionalFeedback;
  final DateTime submittedAt;

  MeetupFeedback({
    required this.id,
    required this.hangoutId,
    required this.userId,
    required this.hangoutTitle,
    required this.didMeetup,
    this.additionalFeedback,
    required this.submittedAt,
  });

  factory MeetupFeedback.fromMap(Map<String, dynamic> map) {
    return MeetupFeedback(
      id: map['id'] ?? '',
      hangoutId: map['hangoutId'] ?? '',
      userId: map['userId'] ?? '',
      hangoutTitle: map['hangoutTitle'] ?? '',
      didMeetup: map['didMeetup'] ?? false,
      additionalFeedback: map['additionalFeedback'],
      submittedAt: (map['submittedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hangoutId': hangoutId,
      'userId': userId,
      'hangoutTitle': hangoutTitle,
      'didMeetup': didMeetup,
      'additionalFeedback': additionalFeedback,
      'submittedAt': Timestamp.fromDate(submittedAt),
    };
  }

  MeetupFeedback copyWith({
    String? id,
    String? hangoutId,
    String? userId,
    String? hangoutTitle,
    bool? didMeetup,
    String? additionalFeedback,
    DateTime? submittedAt,
  }) {
    return MeetupFeedback(
      id: id ?? this.id,
      hangoutId: hangoutId ?? this.hangoutId,
      userId: userId ?? this.userId,
      hangoutTitle: hangoutTitle ?? this.hangoutTitle,
      didMeetup: didMeetup ?? this.didMeetup,
      additionalFeedback: additionalFeedback ?? this.additionalFeedback,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }
}

class PendingFeedbackPrompt {
  final String id;
  final String hangoutId;
  final String userId;
  final String hangoutTitle;
  final DateTime hangoutCompletedAt;
  final DateTime createdAt;
  final bool isShown;
  final DateTime? shownAt;

  PendingFeedbackPrompt({
    required this.id,
    required this.hangoutId,
    required this.userId,
    required this.hangoutTitle,
    required this.hangoutCompletedAt,
    required this.createdAt,
    this.isShown = false,
    this.shownAt,
  });

  factory PendingFeedbackPrompt.fromMap(Map<String, dynamic> map) {
    return PendingFeedbackPrompt(
      id: map['id'] ?? '',
      hangoutId: map['hangoutId'] ?? '',
      userId: map['userId'] ?? '',
      hangoutTitle: map['hangoutTitle'] ?? '',
      hangoutCompletedAt: (map['hangoutCompletedAt'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isShown: map['isShown'] ?? false,
      shownAt: map['shownAt'] != null 
          ? (map['shownAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hangoutId': hangoutId,
      'userId': userId,
      'hangoutTitle': hangoutTitle,
      'hangoutCompletedAt': Timestamp.fromDate(hangoutCompletedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'isShown': isShown,
      'shownAt': shownAt != null ? Timestamp.fromDate(shownAt!) : null,
    };
  }

  PendingFeedbackPrompt copyWith({
    String? id,
    String? hangoutId,
    String? userId,
    String? hangoutTitle,
    DateTime? hangoutCompletedAt,
    DateTime? createdAt,
    bool? isShown,
    DateTime? shownAt,
  }) {
    return PendingFeedbackPrompt(
      id: id ?? this.id,
      hangoutId: hangoutId ?? this.hangoutId,
      userId: userId ?? this.userId,
      hangoutTitle: hangoutTitle ?? this.hangoutTitle,
      hangoutCompletedAt: hangoutCompletedAt ?? this.hangoutCompletedAt,
      createdAt: createdAt ?? this.createdAt,
      isShown: isShown ?? this.isShown,
      shownAt: shownAt ?? this.shownAt,
    );
  }
}

