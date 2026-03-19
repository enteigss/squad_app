import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_app/models/user_model.dart';
import 'package:squad_app/providers/auth_provider.dart';
import 'package:squad_app/services/auth_service.dart';
import 'package:squad_app/services/notification_service.dart';
import 'package:squad_app/services/account_deletion_service.dart';
import 'package:squad_app/services/storage_service.dart';

import '../../fixtures/user_fixtures.dart';
import 'auth_provider_test.mocks.dart';

@GenerateMocks([
  AuthService,
  NotificationService,
  AccountDeletionService,
  StorageService,
])
void main() {
  group('AuthProvider', () {
    late AuthProvider provider;
    late MockAuthService mockAuthService;
    late MockNotificationService mockNotificationService;
    late MockAccountDeletionService mockDeletionService;
    late MockStorageService mockStorageService;
    late StreamController<User?> authStateController;

    setUp(() {
      mockAuthService = MockAuthService();
      mockNotificationService = MockNotificationService();
      mockDeletionService = MockAccountDeletionService();
      mockStorageService = MockStorageService();
      authStateController = StreamController<User?>.broadcast();

      // Default stubs
      when(mockAuthService.authStateChanges)
          .thenAnswer((_) => authStateController.stream);
      when(mockNotificationService.requestPermission())
          .thenAnswer((_) async {});
      when(mockNotificationService.unsubscribeFromTopics(any))
          .thenAnswer((_) async {});
      when(mockNotificationService.subscribeToHangoutTopicsBasedOnGender(any))
          .thenAnswer((_) async {});
      when(mockNotificationService.removeToken())
          .thenAnswer((_) async {});
    });

    AuthProvider createProvider() {
      return AuthProvider(
        authService: mockAuthService,
        notificationService: mockNotificationService,
        deletionService: mockDeletionService,
        storageService: mockStorageService,
      );
    }

    tearDown(() {
      authStateController.close();
    });

    group('initial state', () {
      test('starts unauthenticated with no error', () {
        provider = createProvider();

        expect(provider.currentUser, isNull);
        expect(provider.isAuthenticated, false);
        expect(provider.isLoading, false);
        expect(provider.error, isNull);
        expect(provider.accountDeletionCompleted, false);
      });
    });

    group('auth state changes', () {
      test('sets currentUser when auth state emits a user', () async {
        final testUser = UserFixtures.basicUser;
        when(mockAuthService.getUserData('user-123'))
            .thenAnswer((_) async => testUser);

        provider = createProvider();

        // Simulate Firebase auth emitting a signed-in user
        final mockUser = _FakeUser(uid: 'user-123');
        authStateController.add(mockUser);

        // Allow the async listener to complete
        await Future.delayed(Duration.zero);

        expect(provider.currentUser, isNotNull);
        expect(provider.currentUser!.id, 'user-123');
        expect(provider.isAuthenticated, true);
      });

      test('clears currentUser when auth state emits null', () async {
        final testUser = UserFixtures.basicUser;
        when(mockAuthService.getUserData('user-123'))
            .thenAnswer((_) async => testUser);

        provider = createProvider();

        // Sign in first
        final mockUser = _FakeUser(uid: 'user-123');
        authStateController.add(mockUser);
        await Future.delayed(Duration.zero);
        expect(provider.isAuthenticated, true);

        // Sign out via auth state
        authStateController.add(null);
        await Future.delayed(Duration.zero);

        expect(provider.currentUser, isNull);
        expect(provider.isAuthenticated, false);
      });

      test('sets error when getUserData fails', () async {
        when(mockAuthService.getUserData('user-123'))
            .thenThrow(Exception('Firestore unavailable'));

        provider = createProvider();

        final mockUser = _FakeUser(uid: 'user-123');
        authStateController.add(mockUser);
        await Future.delayed(Duration.zero);

        expect(provider.error, contains('Firestore unavailable'));
        expect(provider.currentUser, isNull);
      });
    });

    group('notification setup on sign-in', () {
      test('requests permissions and subscribes to topics on auth state change', () async {
        final testUser = UserFixtures.basicUser;
        when(mockAuthService.getUserData('user-123'))
            .thenAnswer((_) async => testUser);

        provider = createProvider();

        authStateController.add(_FakeUser(uid: 'user-123'));
        await Future.delayed(Duration.zero);

        verify(mockNotificationService.requestPermission()).called(1);
        verify(mockNotificationService.unsubscribeFromTopics([
          'new_hangouts_bu_men',
          'new_hangouts_bu_women',
          'new_hangouts_bu_anyone',
        ])).called(1);
        verify(mockNotificationService.subscribeToHangoutTopicsBasedOnGender(
          testUser.gender,
        )).called(1);
      });

      test('auth state change succeeds even if notification setup fails', () async {
        final testUser = UserFixtures.basicUser;
        when(mockAuthService.getUserData('user-123'))
            .thenAnswer((_) async => testUser);
        when(mockNotificationService.requestPermission())
            .thenThrow(Exception('Notification error'));

        provider = createProvider();

        authStateController.add(_FakeUser(uid: 'user-123'));
        await Future.delayed(Duration.zero);

        // User should still be set despite notification failure
        expect(provider.currentUser, isNotNull);
        expect(provider.error, isNull);
      });
    });

    group('signInWithGoogle', () {
      test('sets currentUser on successful sign-in', () async {
        final testUser = UserFixtures.basicUser;
        when(mockAuthService.signInWithGoogle())
            .thenAnswer((_) async => testUser);

        provider = createProvider();

        await provider.signInWithGoogle();

        expect(provider.currentUser, isNotNull);
        expect(provider.currentUser!.id, 'user-123');
        expect(provider.isLoading, false);
      });

      test('resets accountDeletionCompleted flag on sign-in', () async {
        final testUser = UserFixtures.basicUser;
        when(mockAuthService.signInWithGoogle())
            .thenAnswer((_) async => testUser);

        provider = createProvider();

        await provider.signInWithGoogle();

        expect(provider.accountDeletionCompleted, false);
      });

      test('throws and sets error when sign-in returns null', () async {
        when(mockAuthService.signInWithGoogle())
            .thenAnswer((_) async => null);

        provider = createProvider();

        await expectLater(
          () => provider.signInWithGoogle(),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to sign in with Google'),
          )),
        );

        expect(provider.isLoading, false);
      });

      test('sets error and rethrows on service exception', () async {
        when(mockAuthService.signInWithGoogle())
            .thenThrow(Exception('Google sign-in failed'));

        provider = createProvider();

        await expectLater(
          () => provider.signInWithGoogle(),
          throwsA(isA<Exception>()),
        );

        expect(provider.error, contains('Google sign-in failed'));
        expect(provider.isLoading, false);
      });

      test('sets up notifications after successful sign-in', () async {
        final testUser = UserFixtures.basicUser;
        when(mockAuthService.signInWithGoogle())
            .thenAnswer((_) async => testUser);

        provider = createProvider();

        await provider.signInWithGoogle();

        verify(mockNotificationService.requestPermission()).called(1);
        verify(mockNotificationService.subscribeToHangoutTopicsBasedOnGender(
          testUser.gender,
        )).called(1);
      });

      test('sign-in succeeds even when notification setup fails', () async {
        final testUser = UserFixtures.basicUser;
        when(mockAuthService.signInWithGoogle())
            .thenAnswer((_) async => testUser);
        when(mockNotificationService.requestPermission())
            .thenThrow(Exception('Notification error'));

        provider = createProvider();

        await provider.signInWithGoogle();

        expect(provider.currentUser, isNotNull);
      });
    });

    group('signInWithApple', () {
      test('sets currentUser on successful sign-in', () async {
        final testUser = UserFixtures.appleUser;
        when(mockAuthService.signInWithApple())
            .thenAnswer((_) async => testUser);

        provider = createProvider();

        await provider.signInWithApple();

        expect(provider.currentUser, isNotNull);
        expect(provider.currentUser!.authProvider, 'apple');
        expect(provider.isLoading, false);
      });

      test('throws when sign-in returns null', () async {
        when(mockAuthService.signInWithApple())
            .thenAnswer((_) async => null);

        provider = createProvider();

        await expectLater(
          () => provider.signInWithApple(),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to sign in with Apple'),
          )),
        );
      });

      test('sets error and rethrows on service exception', () async {
        when(mockAuthService.signInWithApple())
            .thenThrow(Exception('Apple sign-in failed'));

        provider = createProvider();

        await expectLater(
          () => provider.signInWithApple(),
          throwsA(isA<Exception>()),
        );

        expect(provider.error, contains('Apple sign-in failed'));
        expect(provider.isLoading, false);
      });
    });

    group('signInWithEmailPassword', () {
      test('sets currentUser on successful sign-in', () async {
        final testUser = UserFixtures.basicUser;
        when(mockAuthService.signInWithEmailAndPassword(
          email: 'test@bu.edu',
          password: 'password123',
        )).thenAnswer((_) async => testUser);

        provider = createProvider();

        await provider.signInWithEmailPassword(
          email: 'test@bu.edu',
          password: 'password123',
        );

        expect(provider.currentUser, isNotNull);
        expect(provider.currentUser!.email, 'testuser@bu.edu');
        expect(provider.isLoading, false);
      });

      test('throws when sign-in returns null', () async {
        when(mockAuthService.signInWithEmailAndPassword(
          email: 'test@bu.edu',
          password: 'password123',
        )).thenAnswer((_) async => null);

        provider = createProvider();

        await expectLater(
          () => provider.signInWithEmailPassword(
            email: 'test@bu.edu',
            password: 'password123',
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to sign in with email and password'),
          )),
        );
      });

      test('maps FirebaseAuthException to user-friendly error', () async {
        when(mockAuthService.signInWithEmailAndPassword(
          email: 'test@bu.edu',
          password: 'wrong',
        )).thenThrow(FirebaseAuthException(code: 'wrong-password'));

        provider = createProvider();

        await expectLater(
          () => provider.signInWithEmailPassword(
            email: 'test@bu.edu',
            password: 'wrong',
          ),
          throwsA(isA<FirebaseAuthException>()),
        );

        expect(provider.error, 'Incorrect password.');
        expect(provider.isLoading, false);
      });
    });

    group('signOut', () {
      test('clears currentUser and removes FCM token', () async {
        // Set up a signed-in user first
        final testUser = UserFixtures.basicUser;
        when(mockAuthService.signInWithGoogle())
            .thenAnswer((_) async => testUser);
        when(mockAuthService.signOut()).thenAnswer((_) async {});

        provider = createProvider();
        await provider.signInWithGoogle();
        expect(provider.isAuthenticated, true);

        // Sign out
        await provider.signOut();

        expect(provider.currentUser, isNull);
        expect(provider.isAuthenticated, false);
        expect(provider.isLoading, false);
        verify(mockNotificationService.removeToken()).called(1);
        verify(mockAuthService.signOut()).called(1);
      });

      test('sign-out succeeds even when FCM token removal fails', () async {
        final testUser = UserFixtures.basicUser;
        when(mockAuthService.signInWithGoogle())
            .thenAnswer((_) async => testUser);
        when(mockAuthService.signOut()).thenAnswer((_) async {});
        when(mockNotificationService.removeToken())
            .thenThrow(Exception('Token removal failed'));

        provider = createProvider();
        await provider.signInWithGoogle();

        await provider.signOut();

        expect(provider.currentUser, isNull);
        expect(provider.isAuthenticated, false);
      });

      test('sets error and rethrows when signOut fails', () async {
        final testUser = UserFixtures.basicUser;
        when(mockAuthService.signInWithGoogle())
            .thenAnswer((_) async => testUser);
        when(mockAuthService.signOut())
            .thenThrow(Exception('Sign out failed'));

        provider = createProvider();
        await provider.signInWithGoogle();

        await expectLater(
          () => provider.signOut(),
          throwsA(isA<Exception>()),
        );

        expect(provider.error, contains('Sign out failed'));
        expect(provider.isLoading, false);
      });
    });

    group('user profile loading', () {
      test('updateCurrentUser updates state and notifies listeners', () async {
        provider = createProvider();

        final testUser = UserFixtures.basicUser;
        int notifyCount = 0;
        provider.addListener(() => notifyCount++);

        await provider.updateCurrentUser(testUser);

        expect(provider.currentUser, testUser);
        expect(provider.isAuthenticated, true);
        expect(notifyCount, 1);
      });

      test('refreshCurrentUser fetches fresh data from service', () async {
        final testUser = UserFixtures.basicUser;
        final updatedUser = testUser.copyWith(displayName: 'Updated Name');
        when(mockAuthService.signInWithGoogle())
            .thenAnswer((_) async => testUser);
        when(mockAuthService.getUserData('user-123'))
            .thenAnswer((_) async => updatedUser);

        provider = createProvider();
        await provider.signInWithGoogle();

        await provider.refreshCurrentUser();

        expect(provider.currentUser!.displayName, 'Updated Name');
      });

      test('refreshCurrentUser does nothing when not authenticated', () async {
        provider = createProvider();

        await provider.refreshCurrentUser();

        verifyNever(mockAuthService.getUserData(any));
      });
    });

    group('error state handling', () {
      test('clearError resets error to null', () async {
        when(mockAuthService.signInWithGoogle())
            .thenThrow(Exception('Some error'));

        provider = createProvider();

        try {
          await provider.signInWithGoogle();
        } catch (_) {}

        expect(provider.error, isNotNull);

        provider.clearError();

        expect(provider.error, isNull);
      });

      test('_getErrorMessage maps FirebaseAuthException codes', () async {
        // Test via signInWithEmailPassword which calls _getErrorMessage
        final errorCodes = {
          'user-not-found': 'No user found with this email address.',
          'wrong-password': 'Incorrect password.',
          'email-already-in-use': 'An account already exists with this email address.',
          'weak-password': 'Password is too weak. Please choose a stronger password.',
          'invalid-email': 'Please enter a valid email address.',
          'user-disabled': 'This account has been disabled.',
          'too-many-requests': 'Too many attempts. Please try again later.',
          'operation-not-allowed': 'This operation is not allowed.',
          'network-request-failed': 'Network error. Please check your connection.',
        };

        for (final entry in errorCodes.entries) {
          when(mockAuthService.signInWithEmailAndPassword(
            email: anyNamed('email'), password: anyNamed('password'),
          )).thenThrow(FirebaseAuthException(code: entry.key));

          provider = createProvider();

          try {
            await provider.signInWithEmailPassword(
              email: 'test@bu.edu',
              password: 'pass',
            );
          } catch (_) {}

          expect(provider.error, entry.value,
              reason: 'Failed for code: ${entry.key}');
        }
      });

      test('_getErrorMessage strips Exception prefix from regular exceptions', () async {
        when(mockAuthService.signInWithGoogle())
            .thenThrow(Exception('Custom error message'));

        provider = createProvider();

        try {
          await provider.signInWithGoogle();
        } catch (_) {}

        expect(provider.error, 'Custom error message');
      });

      test('loading state toggles during async operations', () async {
        final completer = Completer<UserModel?>();
        when(mockAuthService.signInWithGoogle())
            .thenAnswer((_) => completer.future);

        provider = createProvider();

        final future = provider.signInWithGoogle();

        // Loading should be true while awaiting
        expect(provider.isLoading, true);

        completer.complete(UserFixtures.basicUser);
        await future;

        // Loading should be false after completing
        expect(provider.isLoading, false);
      });
    });

    group('account deletion flow', () {
      test('deleteAccount streams progress and clears user state', () async {
        final testUser = UserFixtures.basicUser;
        when(mockAuthService.signInWithGoogle())
            .thenAnswer((_) async => testUser);
        when(mockDeletionService.deleteUserAccount('user-123'))
            .thenAnswer((_) => Stream.fromIterable([
                  'Starting account deletion process...',
                  'Deleting account data...',
                  'Account deletion completed successfully',
                ]));

        provider = createProvider();
        await provider.signInWithGoogle();

        final steps = await provider.deleteAccount().toList();

        expect(steps, [
          'Starting account deletion process...',
          'Deleting account data...',
          'Account deletion completed successfully',
        ]);
        expect(provider.currentUser, isNull);
        expect(provider.isAuthenticated, false);
        expect(provider.accountDeletionCompleted, true);
      });

      test('deleteAccount yields error when no user is signed in', () async {
        provider = createProvider();

        final steps = await provider.deleteAccount().toList();

        expect(steps, ['Error: No user found']);
      });

      test('deleteAccount rethrows on service failure', () async {
        final testUser = UserFixtures.basicUser;
        when(mockAuthService.signInWithGoogle())
            .thenAnswer((_) async => testUser);
        when(mockDeletionService.deleteUserAccount('user-123'))
            .thenAnswer((_) => Stream.error(Exception('Deletion failed')));

        provider = createProvider();
        await provider.signInWithGoogle();

        await expectLater(
          () => provider.deleteAccount().toList(),
          throwsA(isA<Exception>()),
        );
      });

      test('resetAccountDeletionFlag resets the flag', () {
        provider = createProvider();

        provider.resetAccountDeletionFlag();

        expect(provider.accountDeletionCompleted, false);
      });

      test('hasActiveSubscriptions delegates to deletion service', () async {
        final testUser = UserFixtures.basicUser;
        when(mockAuthService.signInWithGoogle())
            .thenAnswer((_) async => testUser);
        when(mockDeletionService.hasActiveSubscriptions('user-123'))
            .thenAnswer((_) async => true);

        provider = createProvider();
        await provider.signInWithGoogle();

        final result = await provider.hasActiveSubscriptions();

        expect(result, true);
        verify(mockDeletionService.hasActiveSubscriptions('user-123')).called(1);
      });

      test('hasActiveSubscriptions returns false when not authenticated', () async {
        provider = createProvider();

        final result = await provider.hasActiveSubscriptions();

        expect(result, false);
      });

      test('scheduleAccountDeletion delegates to deletion service', () async {
        final testUser = UserFixtures.basicUser;
        final deletionDate = DateTime(2025, 6, 1);
        when(mockAuthService.signInWithGoogle())
            .thenAnswer((_) async => testUser);
        when(mockDeletionService.scheduleAccountDeletion('user-123', deletionDate))
            .thenAnswer((_) async {});

        provider = createProvider();
        await provider.signInWithGoogle();

        await provider.scheduleAccountDeletion(deletionDate);

        verify(mockDeletionService.scheduleAccountDeletion('user-123', deletionDate))
            .called(1);
      });

      test('cancelScheduledDeletion delegates to deletion service', () async {
        final testUser = UserFixtures.basicUser;
        when(mockAuthService.signInWithGoogle())
            .thenAnswer((_) async => testUser);
        when(mockDeletionService.cancelScheduledDeletion('user-123'))
            .thenAnswer((_) async {});

        provider = createProvider();
        await provider.signInWithGoogle();

        await provider.cancelScheduledDeletion();

        verify(mockDeletionService.cancelScheduledDeletion('user-123')).called(1);
      });
    });

    group('reauthenticateUser', () {
      test('returns true on successful reauthentication', () async {
        when(mockAuthService.reauthenticateUser())
            .thenAnswer((_) async => true);

        provider = createProvider();

        final result = await provider.reauthenticateUser();

        expect(result, true);
        expect(provider.error, isNull);
        expect(provider.isLoading, false);
      });

      test('returns false and sets error when reauthentication fails', () async {
        when(mockAuthService.reauthenticateUser())
            .thenAnswer((_) async => false);

        provider = createProvider();

        final result = await provider.reauthenticateUser();

        expect(result, false);
        expect(provider.error, 'Re-authentication failed');
      });

      test('returns false and sets error on exception', () async {
        when(mockAuthService.reauthenticateUser())
            .thenThrow(Exception('Auth error'));

        provider = createProvider();

        final result = await provider.reauthenticateUser();

        expect(result, false);
        expect(provider.error, 'Auth error');
        expect(provider.isLoading, false);
      });
    });

    group('checkUsernameAvailability', () {
      test('returns true when username is available', () async {
        when(mockAuthService.isUsernameAvailable('newname'))
            .thenAnswer((_) async => true);

        provider = createProvider();

        final result = await provider.checkUsernameAvailability('newname');

        expect(result, true);
      });

      test('returns false and sets error on exception', () async {
        when(mockAuthService.isUsernameAvailable('badname'))
            .thenThrow(Exception('Check failed'));

        provider = createProvider();

        final result = await provider.checkUsernameAvailability('badname');

        expect(result, false);
        expect(provider.error, 'Check failed');
      });
    });
  });
}

/// Minimal fake User for auth state stream.
/// Only `uid` is used by AuthProvider._initializeAuth.
class _FakeUser extends Fake implements User {
  @override
  final String uid;

  _FakeUser({required this.uid});

  @override
  String? get email => '$uid@bu.edu';

  @override
  bool get emailVerified => true;
}
