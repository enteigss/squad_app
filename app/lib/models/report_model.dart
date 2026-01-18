import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportStatus { pending, action_taken, dismissed }

enum ReportReason {
  safety_concern,
  harassment_bullying,
  inappropriate_content,
  spam_scam,
  other,
}

extension ReportReasonExtension on ReportReason {
  String get displayName {
    switch (this) {
      case ReportReason.safety_concern:
        return 'Safety Concern';
      case ReportReason.harassment_bullying:
        return 'Harassment & Bullying';
      case ReportReason.inappropriate_content:
        return 'Inappropriate Content';
      case ReportReason.spam_scam:
        return 'Spam/Scam';
      case ReportReason.other:
        return 'Other';
    }
  }

  String get value {
    return name;
  }
}

class ReporterInfo {
  final String uid;
  final String displayName;

  ReporterInfo({
    required this.uid,
    required this.displayName,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
    };
  }

  factory ReporterInfo.fromMap(Map<String, dynamic> map) {
    return ReporterInfo(
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? '',
    );
  }
}

class ReportedContentInfo {
  final String contentType; // 'hangout', 'user'
  final String contentId;
  final String authorId;
  final Map<String, dynamic> contentSnippet;

  ReportedContentInfo({
    required this.contentType,
    required this.contentId,
    required this.authorId,
    required this.contentSnippet,
  });

  Map<String, dynamic> toMap() {
    return {
      'contentType': contentType,
      'contentId': contentId,
      'authorId': authorId,
      'contentSnippet': contentSnippet,
    };
  }

  factory ReportedContentInfo.fromMap(Map<String, dynamic> map) {
    return ReportedContentInfo(
      contentType: map['contentType'] ?? '',
      contentId: map['contentId'] ?? '',
      authorId: map['authorId'] ?? '',
      contentSnippet: Map<String, dynamic>.from(map['contentSnippet'] ?? {}),
    );
  }
}

class Report {
  final String? id;
  final ReportStatus status;
  final DateTime timestamp;
  final ReportReason reason;
  final ReporterInfo reporterInfo;
  final ReportedContentInfo reportedContentInfo;

  Report({
    this.id,
    this.status = ReportStatus.pending,
    required this.timestamp,
    required this.reason,
    required this.reporterInfo,
    required this.reportedContentInfo,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'reason': reason.value,
      'reporterInfo': reporterInfo.toMap(),
      'reportedContentInfo': reportedContentInfo.toMap(),
    };
  }

  factory Report.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Report(
      id: documentId ?? map['id'],
      status: ReportStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => ReportStatus.pending,
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      reason: ReportReason.values.firstWhere(
        (reason) => reason.value == map['reason'],
        orElse: () => ReportReason.other,
      ),
      reporterInfo: ReporterInfo.fromMap(map['reporterInfo'] ?? {}),
      reportedContentInfo: ReportedContentInfo.fromMap(map['reportedContentInfo'] ?? {}),
    );
  }

  Report copyWith({
    String? id,
    ReportStatus? status,
    DateTime? timestamp,
    ReportReason? reason,
    ReporterInfo? reporterInfo,
    ReportedContentInfo? reportedContentInfo,
  }) {
    return Report(
      id: id ?? this.id,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      reason: reason ?? this.reason,
      reporterInfo: reporterInfo ?? this.reporterInfo,
      reportedContentInfo: reportedContentInfo ?? this.reportedContentInfo,
    );
  }
}