import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_app/models/report_model.dart';
import 'package:squad_app/services/report_service.dart';

import 'report_service_test.mocks.dart';

@GenerateMocks([FirebaseFunctions])
@GenerateNiceMocks([
  MockSpec<HttpsCallable>(),
  MockSpec<HttpsCallableResult<dynamic>>(),
])
void main() {
  group('ReportService', () {
    late ReportService reportService;
    late MockFirebaseFunctions mockFunctions;
    late MockHttpsCallable mockCallable;
    late MockHttpsCallableResult mockResult;
    late MockFirebaseAuth mockAuth;

    const testUserId = 'user-123';
    const testDisplayName = 'Test User';
    const testContentType = 'hangout';
    const testContentId = 'hangout-123';
    const testContentTitle = 'Beach Volleyball';
    const testAuthorId = 'author-456';
    final testContentSnippet = {
      'hangout_title': 'Beach Volleyball',
      'hangout_description': 'Fun game',
    };
    const testReason = ReportReason.harassment_bullying;

    setUp(() {
      mockFunctions = MockFirebaseFunctions();
      mockCallable = MockHttpsCallable();
      mockResult = MockHttpsCallableResult();
      mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: testUserId, isAnonymous: false),
      );
      reportService = ReportService(
        functions: mockFunctions,
        auth: mockAuth,
      );
    });

    void setupSuccessfulCallMocks({
      Map<String, dynamic> responseData = const {
        'success': true,
        'reportId': 'report-abc',
      },
    }) {
      when(mockFunctions.httpsCallable('submitReport'))
          .thenReturn(mockCallable);
      when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
      when(mockResult.data).thenReturn(responseData);
    }

    Future<void> callSubmitReport() => reportService.submitReport(
          contentType: testContentType,
          contentId: testContentId,
          contentTitle: testContentTitle,
          authorId: testAuthorId,
          contentSnippet: testContentSnippet,
          reason: testReason,
          reporterUid: testUserId,
          reporterDisplayName: testDisplayName,
        );

    group('submitReport', () {
      test('throws when user is not authenticated', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(signedIn: false);
        reportService = ReportService(
          functions: mockFunctions,
          auth: mockAuth,
        );

        // Act & Assert
        await expectLater(
          callSubmitReport,
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Authentication failed. Please sign in again.'),
            ),
          ),
        );
      });

      test('calls cloud function with correct data structure', () async {
        // Arrange
        setupSuccessfulCallMocks();

        // Act
        await callSubmitReport();

        // Assert
        verify(mockFunctions.httpsCallable('submitReport')).called(1);

        final captured =
            verify(mockCallable.call(captureAny)).captured.single
                as Map<String, dynamic>;

        expect(captured['status'], 'pending');
        expect(captured['timestamp'], isNotNull);
        expect(captured['reason'], 'harassment_bullying');
        expect(captured['reporterInfo'], {
          'uid': testUserId,
          'displayName': testDisplayName,
        });
        expect(captured['reportedContentInfo']['contentType'], testContentType);
        expect(captured['reportedContentInfo']['contentId'], testContentId);
        expect(captured['reportedContentInfo']['authorId'], testAuthorId);
        expect(
          captured['reportedContentInfo']['contentSnippet'],
          testContentSnippet,
        );
      });

      test('completes successfully on success response', () async {
        // Arrange
        setupSuccessfulCallMocks(
          responseData: {'success': true, 'reportId': 'report-abc'},
        );

        // Act & Assert — should complete without throwing
        await callSubmitReport();
      });

      test('throws when cloud function returns failure response', () async {
        // Arrange
        setupSuccessfulCallMocks(
          responseData: {'success': false, 'message': 'Rate limit exceeded'},
        );

        // Act & Assert
        await expectLater(
          callSubmitReport,
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to submit report'),
            ),
          ),
        );
      });

      test('throws default message when failure response has no message',
          () async {
        // Arrange
        setupSuccessfulCallMocks(responseData: {'success': false});

        // Act & Assert
        await expectLater(
          callSubmitReport,
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to submit report'),
            ),
          ),
        );
      });

      test('handles FirebaseFunctionsException', () async {
        // Arrange
        when(mockFunctions.httpsCallable('submitReport'))
            .thenReturn(mockCallable);
        when(mockCallable.call(any)).thenThrow(
          // ignore: invalid_use_of_protected_member
          FirebaseFunctionsException(
            code: 'not-found',
            message: 'Function not found',
          ),
        );

        // Act & Assert
        await expectLater(
          callSubmitReport,
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Function not found'),
            ),
          ),
        );
      });

      test('handles generic errors', () async {
        // Arrange
        when(mockFunctions.httpsCallable('submitReport'))
            .thenReturn(mockCallable);
        when(mockCallable.call(any)).thenThrow(Exception('Network timeout'));

        // Act & Assert
        await expectLater(
          callSubmitReport,
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to submit report'),
            ),
          ),
        );
      });
    });

    group('createHangoutContentSnippet', () {
      test('returns map with required fields only', () {
        // Act
        final result = ReportService.createHangoutContentSnippet(
          title: 'Beach Day',
          description: 'Fun at the beach',
        );

        // Assert
        expect(result, {
          'hangout_title': 'Beach Day',
          'hangout_description': 'Fun at the beach',
        });
        expect(result.containsKey('location'), false);
        expect(result.containsKey('participant_count'), false);
        expect(result.containsKey('scheduled_time'), false);
      });

      test('returns map with all fields including optional', () {
        // Arrange
        final scheduledTime = DateTime(2025, 6, 15, 14, 30);

        // Act
        final result = ReportService.createHangoutContentSnippet(
          title: 'Beach Day',
          description: 'Fun at the beach',
          location: 'Santa Monica',
          participantCount: 5,
          scheduledTime: scheduledTime,
        );

        // Assert
        expect(result['hangout_title'], 'Beach Day');
        expect(result['hangout_description'], 'Fun at the beach');
        expect(result['location'], 'Santa Monica');
        expect(result['participant_count'], 5);
        expect(result['scheduled_time'], scheduledTime.toIso8601String());
      });
    });

    group('createUserContentSnippet', () {
      test('returns map with required fields only', () {
        // Act
        final result = ReportService.createUserContentSnippet(
          displayName: 'John Doe',
        );

        // Assert
        expect(result, {'user_display_name': 'John Doe'});
        expect(result.containsKey('bio'), false);
        expect(result.containsKey('location'), false);
        expect(result.containsKey('interests'), false);
      });

      test('returns map with all fields including optional', () {
        // Act
        final result = ReportService.createUserContentSnippet(
          displayName: 'John Doe',
          bio: 'Love hiking',
          location: 'Boston, MA',
          interests: ['hiking', 'cooking', 'reading'],
        );

        // Assert
        expect(result['user_display_name'], 'John Doe');
        expect(result['bio'], 'Love hiking');
        expect(result['location'], 'Boston, MA');
        expect(result['interests'], ['hiking', 'cooking', 'reading']);
      });
    });
  });
}
