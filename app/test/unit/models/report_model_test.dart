import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:squad_app/models/report_model.dart';

void main() {
  final fixedDate = DateTime(2024, 1, 1, 12, 0, 0);

  group('ReportReason', () {
    test('displayName returns correct values', () {
      expect(ReportReason.safety_concern.displayName, 'Safety Concern');
      expect(ReportReason.harassment_bullying.displayName, 'Harassment & Bullying');
      expect(ReportReason.inappropriate_content.displayName, 'Inappropriate Content');
      expect(ReportReason.spam_scam.displayName, 'Spam/Scam');
      expect(ReportReason.other.displayName, 'Other');
    });

    test('value returns enum name', () {
      expect(ReportReason.safety_concern.value, 'safety_concern');
      expect(ReportReason.harassment_bullying.value, 'harassment_bullying');
    });
  });

  group('ReporterInfo', () {
    test('fromMap creates ReporterInfo correctly', () {
      final map = {
        'uid': 'user-123',
        'displayName': 'Reporter Name',
      };

      final info = ReporterInfo.fromMap(map);

      expect(info.uid, 'user-123');
      expect(info.displayName, 'Reporter Name');
    });

    test('toMap converts ReporterInfo correctly', () {
      final info = ReporterInfo(
        uid: 'user-123',
        displayName: 'Reporter Name',
      );

      final map = info.toMap();

      expect(map['uid'], 'user-123');
      expect(map['displayName'], 'Reporter Name');
    });

    test('handles null values with defaults', () {
      final map = <String, dynamic>{
        'uid': null,
        'displayName': null,
      };

      final info = ReporterInfo.fromMap(map);

      expect(info.uid, '');
      expect(info.displayName, '');
    });
  });

  group('ReportedContentInfo', () {
    test('fromMap creates ReportedContentInfo correctly', () {
      final map = {
        'contentType': 'hangout',
        'contentId': 'hangout-123',
        'authorId': 'author-123',
        'contentSnippet': {'title': 'Lunch meetup', 'description': 'Join us'},
      };

      final info = ReportedContentInfo.fromMap(map);

      expect(info.contentType, 'hangout');
      expect(info.contentId, 'hangout-123');
      expect(info.authorId, 'author-123');
      expect(info.contentSnippet['title'], 'Lunch meetup');
      expect(info.contentSnippet['description'], 'Join us');
    });

    test('toMap converts ReportedContentInfo correctly', () {
      final info = ReportedContentInfo(
        contentType: 'user',
        contentId: 'user-456',
        authorId: 'user-456',
        contentSnippet: {'displayName': 'Bad User'},
      );

      final map = info.toMap();

      expect(map['contentType'], 'user');
      expect(map['contentId'], 'user-456');
      expect(map['authorId'], 'user-456');
      expect(map['contentSnippet'], {'displayName': 'Bad User'});
    });

    test('handles null contentSnippet with empty map', () {
      final map = {
        'contentType': 'hangout',
        'contentId': 'hangout-123',
        'authorId': 'author-123',
        'contentSnippet': null,
      };

      final info = ReportedContentInfo.fromMap(map);

      expect(info.contentSnippet, isEmpty);
    });
  });

  group('Report', () {
    group('fromMap', () {
      test('creates Report from valid map', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('reports').doc('report-123').set({
          'status': 'pending',
          'timestamp': Timestamp.fromDate(fixedDate),
          'reason': 'safety_concern',
          'reporterInfo': {
            'uid': 'reporter-123',
            'displayName': 'Reporter',
          },
          'reportedContentInfo': {
            'contentType': 'hangout',
            'contentId': 'hangout-123',
            'authorId': 'author-123',
            'contentSnippet': {'title': 'Test'},
          },
        });

        final doc =
            await firestore.collection('reports').doc('report-123').get();
        final report =
            Report.fromMap(doc.data()!, documentId: 'report-123');

        expect(report.id, 'report-123');
        expect(report.status, ReportStatus.pending);
        expect(report.reason, ReportReason.safety_concern);
        expect(report.reporterInfo.uid, 'reporter-123');
        expect(report.reportedContentInfo.contentType, 'hangout');
      });

      test('handles all ReportStatus values', () async {
        final firestore = FakeFirebaseFirestore();

        for (final status in ReportStatus.values) {
          await firestore.collection('reports').doc(status.name).set({
            'status': status.name,
            'timestamp': Timestamp.fromDate(fixedDate),
            'reason': 'other',
            'reporterInfo': {'uid': 'user', 'displayName': 'User'},
            'reportedContentInfo': {
              'contentType': 'user',
              'contentId': 'id',
              'authorId': 'id',
              'contentSnippet': {},
            },
          });

          final doc =
              await firestore.collection('reports').doc(status.name).get();
          final report = Report.fromMap(doc.data()!);
          expect(report.status, status);
        }
      });

      test('handles all ReportReason values', () async {
        final firestore = FakeFirebaseFirestore();

        for (final reason in ReportReason.values) {
          await firestore.collection('reports').doc(reason.name).set({
            'status': 'pending',
            'timestamp': Timestamp.fromDate(fixedDate),
            'reason': reason.value,
            'reporterInfo': {'uid': 'user', 'displayName': 'User'},
            'reportedContentInfo': {
              'contentType': 'user',
              'contentId': 'id',
              'authorId': 'id',
              'contentSnippet': {},
            },
          });

          final doc =
              await firestore.collection('reports').doc(reason.name).get();
          final report = Report.fromMap(doc.data()!);
          expect(report.reason, reason);
        }
      });

      test('handles invalid enum values with defaults', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('reports').doc('test').set({
          'status': 'invalid_status',
          'timestamp': Timestamp.fromDate(fixedDate),
          'reason': 'invalid_reason',
          'reporterInfo': {'uid': 'user', 'displayName': 'User'},
          'reportedContentInfo': {
            'contentType': 'user',
            'contentId': 'id',
            'authorId': 'id',
            'contentSnippet': {},
          },
        });

        final doc = await firestore.collection('reports').doc('test').get();
        final report = Report.fromMap(doc.data()!);

        expect(report.status, ReportStatus.pending);
        expect(report.reason, ReportReason.other);
      });
    });

    group('toMap', () {
      test('converts Report to map correctly', () {
        final report = Report(
          id: 'report-123',
          status: ReportStatus.pending,
          timestamp: fixedDate,
          reason: ReportReason.harassment_bullying,
          reporterInfo: ReporterInfo(
            uid: 'reporter-123',
            displayName: 'Reporter',
          ),
          reportedContentInfo: ReportedContentInfo(
            contentType: 'hangout',
            contentId: 'hangout-123',
            authorId: 'author-123',
            contentSnippet: {'title': 'Bad hangout'},
          ),
        );

        final map = report.toMap();

        expect(map['id'], 'report-123');
        expect(map['status'], 'pending');
        expect(map['reason'], 'harassment_bullying');
        expect(map['timestamp'], isA<Timestamp>());
        expect(map['reporterInfo']['uid'], 'reporter-123');
        expect(map['reportedContentInfo']['contentType'], 'hangout');
      });

      test('excludes id from map when null', () {
        final report = Report(
          status: ReportStatus.pending,
          timestamp: fixedDate,
          reason: ReportReason.spam_scam,
          reporterInfo: ReporterInfo(uid: 'user', displayName: 'User'),
          reportedContentInfo: ReportedContentInfo(
            contentType: 'user',
            contentId: 'id',
            authorId: 'id',
            contentSnippet: {},
          ),
        );

        final map = report.toMap();

        expect(map.containsKey('id'), false);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = Report(
          id: 'report-123',
          status: ReportStatus.pending,
          timestamp: fixedDate,
          reason: ReportReason.spam_scam,
          reporterInfo: ReporterInfo(uid: 'user', displayName: 'User'),
          reportedContentInfo: ReportedContentInfo(
            contentType: 'user',
            contentId: 'id',
            authorId: 'id',
            contentSnippet: {},
          ),
        );

        final copy = original.copyWith(
          status: ReportStatus.action_taken,
        );

        expect(copy.status, ReportStatus.action_taken);
        expect(copy.id, original.id);
        expect(copy.reason, original.reason);
      });
    });
  });
}
