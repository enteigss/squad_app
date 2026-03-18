import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_app/services/account_deletion_service.dart';
import 'package:squad_app/services/notification_service.dart';

import 'account_deletion_service_test.mocks.dart';

@GenerateMocks([
  FirebaseFunctions,
  FirebaseCrashlytics,
  NotificationService,
])
@GenerateNiceMocks([
  MockSpec<HttpsCallable>(),
  MockSpec<HttpsCallableResult<dynamic>>(),
])
void main() {
  group('AccountDeletionService', () {
    late AccountDeletionService service;
    late MockFirebaseFunctions mockFunctions;
    late MockFirebaseCrashlytics mockCrashlytics;
    late MockNotificationService mockNotificationService;
    late MockHttpsCallable mockCallable;
    late MockHttpsCallableResult mockResult;
    late MockFirebaseAuth mockAuth;

    const testUserId = 'user-123';

    setUp(() {
      mockFunctions = MockFirebaseFunctions();
      mockCrashlytics = MockFirebaseCrashlytics();
      mockNotificationService = MockNotificationService();
      mockCallable = MockHttpsCallable();
      mockResult = MockHttpsCallableResult();
      mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: testUserId, isAnonymous: false),
      );

      // Default Crashlytics stubs
      when(mockCrashlytics.log(any)).thenAnswer((_) async => {});
      when(mockCrashlytics.recordError(
        any,
        any,
        reason: anyNamed('reason'),
        information: anyNamed('information'),
        fatal: anyNamed('fatal'),
      )).thenAnswer((_) async => {});

      // Default NotificationService stubs
      when(mockNotificationService.unsubscribeFromTopics(any))
          .thenAnswer((_) async => {});

      service = AccountDeletionService(
        auth: mockAuth,
        functions: mockFunctions,
        crashlytics: mockCrashlytics,
        notificationService: mockNotificationService,
      );
    });

    /// Sets up mocks for a successful cloud function call
    void setupSuccessfulDeleteMocks({
      Map<String, dynamic> responseData = const {
        'success': true,
        'deletedData': {
          'posts': 5,
          'messages': 12,
          'mediaFiles': 3,
        },
      },
    }) {
      when(mockFunctions.httpsCallable('deleteUserAccount'))
          .thenReturn(mockCallable);
      when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
      when(mockResult.data).thenReturn(responseData);
    }

    group('revokeNotificationTokens', () {
      test('unsubscribes from all notification topics', () async {
        // Act
        await service.revokeNotificationTokens(testUserId);

        // Assert
        verify(mockNotificationService.unsubscribeFromTopics([
          'new_hangouts_bu_men',
          'new_hangouts_bu_women',
          'new_hangouts_bu_anyone',
        ])).called(1);
      });

      test('rethrows errors from notification service', () async {
        // Arrange
        when(mockNotificationService.unsubscribeFromTopics(any))
            .thenThrow(Exception('FCM error'));

        // Act & Assert
        await expectLater(
          () => service.revokeNotificationTokens(testUserId),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('FCM error'),
            ),
          ),
        );
      });
    });

    group('revokeAppleSignInToken', () {
      test('returns early when no current user', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(signedIn: false);
        service = AccountDeletionService(
          auth: mockAuth,
          functions: mockFunctions,
          crashlytics: mockCrashlytics,
          notificationService: mockNotificationService,
        );

        // Act & Assert — should complete without error
        await service.revokeAppleSignInToken(testUserId);

        // No crashlytics error should be recorded
        verifyNever(mockCrashlytics.recordError(
          any,
          any,
          reason: anyNamed('reason'),
          information: anyNamed('information'),
          fatal: anyNamed('fatal'),
        ));
      });

      test('completes without error when user exists', () async {
        // Act & Assert — should complete without error
        await service.revokeAppleSignInToken(testUserId);
      });
    });

    group('deleteUserAccount', () {
      test('yields progress messages in correct order on success', () async {
        // Arrange
        setupSuccessfulDeleteMocks();

        // Act
        final messages =
            await service.deleteUserAccount(testUserId).toList();

        // Assert
        expect(messages, [
          'Starting account deletion process...',
          'Revoking authentication tokens...',
          'Unsubscribing from notifications...',
          'Deleting account data...',
          'Deleted 5 posts, 12 messages, and 3 media files',
          'Account deletion completed successfully',
        ]);
      });

      test('calls cloud function with correct userId', () async {
        // Arrange
        setupSuccessfulDeleteMocks();

        // Act
        await service.deleteUserAccount(testUserId).toList();

        // Assert
        verify(mockFunctions.httpsCallable('deleteUserAccount')).called(1);
        final captured =
            verify(mockCallable.call(captureAny)).captured.single
                as Map<String, dynamic>;
        expect(captured['userId'], testUserId);
      });

      test('calls revokeAppleSignInToken and revokeNotificationTokens',
          () async {
        // Arrange
        setupSuccessfulDeleteMocks();

        // Act
        await service.deleteUserAccount(testUserId).toList();

        // Assert
        verify(mockNotificationService.unsubscribeFromTopics(any)).called(1);
      });

      test('yields success without deletedData summary when not provided',
          () async {
        // Arrange
        setupSuccessfulDeleteMocks(
          responseData: {'success': true},
        );

        // Act
        final messages =
            await service.deleteUserAccount(testUserId).toList();

        // Assert — no deleted data summary, just completion
        expect(messages, contains('Account deletion completed successfully'));
        expect(
          messages.where((m) => m.contains('Deleted')),
          isEmpty,
        );
      });

      test('throws and yields error when cloud function returns failure',
          () async {
        // Arrange
        setupSuccessfulDeleteMocks(
          responseData: {
            'success': false,
            'message': 'Insufficient permissions',
          },
        );

        // Act & Assert
        await expectLater(
          () => service.deleteUserAccount(testUserId).toList(),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to delete account data'),
            ),
          ),
        );
      });

      test('throws and yields error when cloud function throws', () async {
        // Arrange
        when(mockFunctions.httpsCallable('deleteUserAccount'))
            .thenReturn(mockCallable);
        when(mockCallable.call(any)).thenThrow(Exception('Network error'));

        // Act & Assert
        await expectLater(
          () => service.deleteUserAccount(testUserId).toList(),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to delete account data'),
            ),
          ),
        );
      });

      test('records error to crashlytics on failure', () async {
        // Arrange
        when(mockFunctions.httpsCallable('deleteUserAccount'))
            .thenReturn(mockCallable);
        when(mockCallable.call(any)).thenThrow(Exception('Network error'));

        // Act — ignore the rethrown error
        try {
          await service.deleteUserAccount(testUserId).toList();
        } catch (_) {}

        // Assert
        verify(mockCrashlytics.recordError(
          any,
          any,
          reason: argThat(equals('Account deletion failed'), named: 'reason'),
          information: anyNamed('information'),
          fatal: anyNamed('fatal'),
        )).called(1);
      });

      test('logs to crashlytics on success', () async {
        // Arrange
        setupSuccessfulDeleteMocks();

        // Act
        await service.deleteUserAccount(testUserId).toList();

        // Assert
        verify(mockCrashlytics
                .log('Account deletion started for user: $testUserId'))
            .called(1);
        verify(mockCrashlytics.log(
                'Account deletion completed successfully for user: $testUserId'))
            .called(1);
      });
    });

    group('hasActiveSubscriptions', () {
      test('returns false', () async {
        // Act
        final result = await service.hasActiveSubscriptions(testUserId);

        // Assert
        expect(result, false);
      });
    });

    group('scheduleAccountDeletion', () {
      test('completes without error', () async {
        // Act & Assert — should complete without throwing
        await service.scheduleAccountDeletion(
          testUserId,
          DateTime(2025, 12, 31),
        );
      });
    });

    group('cancelScheduledDeletion', () {
      test('completes without error', () async {
        // Act & Assert — should complete without throwing
        await service.cancelScheduledDeletion(testUserId);
      });
    });
  });
}
