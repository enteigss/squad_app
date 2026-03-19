import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_app/models/user_model.dart';
import 'package:squad_app/services/auth_service.dart';

import '../../fixtures/user_fixtures.dart';
import 'auth_service_test.mocks.dart' hide MockUserCredential;

// Generate mocks for dependencies that aren't covered by existing packages
@GenerateMocks(
  [
    FirebaseAnalytics,
    FirebaseCrashlytics,
    GoogleSignIn,
    GoogleSignInAccount,
    GoogleSignInAuthentication,
  ],
  customMocks: [
    MockSpec<UserCredential>(as: #MockUserCredential),
    MockSpec<UserInfo>(as: #MockUserInfo),
  ],
)
MockUserInfo _appleUserInfo() {
  final info = MockUserInfo();
  when(info.providerId).thenReturn('apple.com');
  when(info.uid).thenReturn('apple-id-12345');
  return info;
}

void main() {
  group('AuthService', () {
    late AuthService authService;
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAnalytics mockAnalytics;
    late MockFirebaseCrashlytics mockCrashlytics;
    late MockGoogleSignIn mockGoogleSignIn;

    AuthService createAuthService(MockFirebaseAuth auth) {
      return AuthService(
        auth: auth,
        analytics: mockAnalytics,
        firestore: fakeFirestore,
        getGoogleSignIn: () => mockGoogleSignIn,
        getCrashlytics: () => mockCrashlytics,
      );
    }

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAnalytics = MockFirebaseAnalytics();
      mockCrashlytics = MockFirebaseCrashlytics();
      mockGoogleSignIn = MockGoogleSignIn();

      // Set up default mock behaviors
      when(mockCrashlytics.log(any)).thenAnswer((_) async => {});
      when(mockCrashlytics.setCustomKey(any, any)).thenAnswer((_) async => {});
      when(
        mockCrashlytics.recordError(
          any,
          any,
          reason: anyNamed('reason'),
          information: anyNamed('information'),
          fatal: anyNamed('fatal'),
        ),
      ).thenAnswer((_) async => {});
      when(
        mockAnalytics.setUserId(id: anyNamed('id')),
      ).thenAnswer((_) async => {});

      mockAuth = MockFirebaseAuth(
        mockUser: MockUser(
          uid: 'default-uid',
          email: 'test@bu.edu',
          isAnonymous: false,
        ),
      );
      authService = createAuthService(mockAuth);
    });

    group('signInWithEmailAndPassword', () {
      const email = 'test@bu.edu';
      const password = 'password123';
      const userId = 'user-123';

      test('successful sign-in with existing user', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(
          mockUser: MockUser(uid: userId, email: email, isAnonymous: false),
        );
        authService = createAuthService(mockAuth);

        final existingUser = UserFixtures.custom(
          id: userId,
          email: email,
          hasCreatedProfile: true,
        );
        await fakeFirestore
            .collection('users')
            .doc(userId)
            .set(existingUser.toMap());

        // Act
        final result = await authService.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.id, userId);
        expect(result.email, email);

        // Verify online status was updated
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        expect(userDoc.data()?['isOnline'], true);
        expect(userDoc.data()?['lastSeen'], isNotNull);

        // Verify Crashlytics logs
        verify(
          mockCrashlytics.log('Email/Password Sign-In attempt started'),
        ).called(1);
        verify(
          mockCrashlytics.log(
            'Email/Password Sign-In completed successfully (existing user)',
          ),
        ).called(1);
      });

      test(
        'successful sign-in creates new user document when missing',
        () async {
          // Arrange
          mockAuth = MockFirebaseAuth(
            mockUser: MockUser(uid: userId, email: email, isAnonymous: false),
          );
          authService = createAuthService(mockAuth);

          // Act
          final result = await authService.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          // Assert
          expect(result, isNotNull);
          expect(result!.id, userId);
          expect(result.email, email);
          expect(result.username, 'test'); // From email prefix
          expect(result.hasCreatedProfile, false);
          expect(result.authProvider, 'email');
          expect(result.isEmailVerified, true);

          // Verify user document was created
          final userDoc = await fakeFirestore
              .collection('users')
              .doc(userId)
              .get();
          expect(userDoc.exists, true);
          expect(userDoc.data()?['email'], email);
          expect(userDoc.data()?['isOnline'], true);
        },
      );

      test('throws exception for user-not-found error', () async {
        // Arrange
        whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
            .on(mockAuth)
            .thenThrow(FirebaseAuthException(code: 'user-not-found'));

        // Act & Assert
        await expectLater(
          () => authService.signInWithEmailAndPassword(
            email: email,
            password: password,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('No account found with this email'),
            ),
          ),
        );

        // Verify error was logged
        verify(
          mockCrashlytics.recordError(
            any,
            any,
            reason: 'Email/Password Sign-In failed',
            information: anyNamed('information'),
            fatal: false,
          ),
        ).called(1);
      });

      test('throws exception for wrong-password error', () async {
        // Arrange
        whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
            .on(mockAuth)
            .thenThrow(FirebaseAuthException(code: 'wrong-password'));

        // Act & Assert
        await expectLater(
          () => authService.signInWithEmailAndPassword(
            email: email,
            password: password,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Incorrect password'),
            ),
          ),
        );
      });

      test('throws exception for invalid-email error', () async {
        // Arrange
        whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
            .on(mockAuth)
            .thenThrow(FirebaseAuthException(code: 'invalid-email'));

        // Act & Assert
        await expectLater(
          () => authService.signInWithEmailAndPassword(
            email: email,
            password: password,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Invalid email format'),
            ),
          ),
        );
      });

      test('throws exception for user-disabled error', () async {
        // Arrange
        whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
            .on(mockAuth)
            .thenThrow(FirebaseAuthException(code: 'user-disabled'));

        // Act & Assert
        await expectLater(
          () => authService.signInWithEmailAndPassword(
            email: email,
            password: password,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('This account has been disabled'),
            ),
          ),
        );
      });

      test('throws exception for too-many-requests error', () async {
        // Arrange
        whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
            .on(mockAuth)
            .thenThrow(FirebaseAuthException(code: 'too-many-requests'));

        // Act & Assert
        await expectLater(
          () => authService.signInWithEmailAndPassword(
            email: email,
            password: password,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Too many failed attempts'),
            ),
          ),
        );
      });

      test('throws exception for invalid-credential error', () async {
        // Arrange
        whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
            .on(mockAuth)
            .thenThrow(FirebaseAuthException(code: 'invalid-credential'));

        // Act & Assert
        await expectLater(
          () => authService.signInWithEmailAndPassword(
            email: email,
            password: password,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Invalid email or password'),
            ),
          ),
        );
      });

      test('rethrows unhandled FirebaseAuthException codes', () async {
        // Arrange
        whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
            .on(mockAuth)
            .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

        // Act & Assert
        await expectLater(
          () => authService.signInWithEmailAndPassword(
            email: email,
            password: password,
          ),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'network-request-failed',
            ),
          ),
        );
      });
    });

    group('signUpWithEmailAndPassword', () {
      const email = 'newuser@bu.edu';
      const password = 'password123';

      test('successful sign-up creates user document', () async {
        // Act
        final result = await authService.signUpWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.email, email);
        expect(result.username, 'newuser');
        expect(result.hasCreatedProfile, false);
        expect(result.authProvider, 'email');
        expect(result.isOnline, true);

        // Verify user document was created (UID is auto-generated)
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(result.id)
            .get();
        expect(userDoc.exists, true);
        expect(userDoc.data()?['email'], email);
        expect(userDoc.data()?['isEmailVerified'], true);
      });

      test('throws exception for weak-password error', () async {
        // Arrange
        whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
            .on(mockAuth)
            .thenThrow(FirebaseAuthException(code: 'weak-password'));

        // Act & Assert
        await expectLater(
          () => authService.signUpWithEmailAndPassword(
            email: email,
            password: password,
          ),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'weak-password',
            ),
          ),
        );
      });

      test('throws exception for email-already-in-use error', () async {
        // Arrange
        whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
            .on(mockAuth)
            .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

        // Act & Assert
        await expectLater(
          () => authService.signUpWithEmailAndPassword(
            email: email,
            password: password,
          ),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'email-already-in-use',
            ),
          ),
        );
      });
    });

    group('signInWithGoogle', () {
      const email = 'test@bu.edu';
      const userId = 'google-user-123';

      test('successful sign-in with new BU user', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(
          mockUser: MockUser(
            uid: userId,
            email: email,
            displayName: 'Test User',
            photoURL: 'https://example.com/photo.jpg',
            isAnonymous: false,
          ),
        );
        authService = createAuthService(mockAuth);

        final mockGoogleAccount = MockGoogleSignInAccount();
        final mockGoogleAuth = MockGoogleSignInAuthentication();

        when(mockGoogleSignIn.supportsAuthenticate()).thenReturn(true);
        when(
          mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) async => mockGoogleAccount);
        when(mockGoogleAccount.email).thenReturn(email);
        when(mockGoogleAccount.authentication).thenReturn(mockGoogleAuth);
        when(mockGoogleAuth.idToken).thenReturn('fake-id-token');

        // Act
        final result = await authService.signInWithGoogle();

        // Assert
        expect(result, isNotNull);
        expect(result!.id, userId);
        expect(result.email, email);
        expect(result.username, 'test');
        expect(result.displayName, 'Test User');
        expect(result.photoUrl, 'https://example.com/photo.jpg');
        expect(result.authProvider, 'google');
        expect(result.hasCreatedProfile, false);
        expect(result.isOnline, true);

        // Verify user document was created
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        expect(userDoc.exists, true);
        expect(userDoc.data()?['authProvider'], 'google');
        expect(userDoc.data()?['isEmailVerified'], true);

        // Verify analytics was set
        verify(mockAnalytics.setUserId(id: userId)).called(1);
      });

      test('successful sign-in with existing user', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(
          mockUser: MockUser(uid: userId, email: email, isAnonymous: false),
        );
        authService = createAuthService(mockAuth);

        final existingUser = UserFixtures.custom(
          id: userId,
          email: email,
          hasCreatedProfile: true,
        );
        await fakeFirestore
            .collection('users')
            .doc(userId)
            .set(existingUser.toMap());

        final mockGoogleAccount = MockGoogleSignInAccount();
        final mockGoogleAuth = MockGoogleSignInAuthentication();

        when(mockGoogleSignIn.supportsAuthenticate()).thenReturn(true);
        when(
          mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) async => mockGoogleAccount);
        when(mockGoogleAccount.email).thenReturn(email);
        when(mockGoogleAccount.authentication).thenReturn(mockGoogleAuth);
        when(mockGoogleAuth.idToken).thenReturn('fake-id-token');

        // Act
        final result = await authService.signInWithGoogle();

        // Assert
        expect(result, isNotNull);
        expect(result!.id, userId);
        expect(result.email, email);

        // Verify online status was updated
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        expect(userDoc.data()?['isOnline'], true);
      });

      test('returns null when user cancels authentication', () async {
        // Arrange
        when(mockGoogleSignIn.supportsAuthenticate()).thenReturn(true);
        when(
          mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) async => throw Exception('User cancelled'));

        // Act
        final result = await authService.signInWithGoogle();

        // Assert
        expect(result, isNull);
      });

      test('throws FirebaseAuthException on credential error', () async {
        // Arrange
        final mockGoogleAccount = MockGoogleSignInAccount();
        final mockGoogleAuth = MockGoogleSignInAuthentication();

        when(mockGoogleSignIn.supportsAuthenticate()).thenReturn(true);
        when(
          mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) async => mockGoogleAccount);
        when(mockGoogleAccount.email).thenReturn(email);
        when(mockGoogleAccount.authentication).thenReturn(mockGoogleAuth);
        when(mockGoogleAuth.idToken).thenReturn('fake-id-token');

        whenCalling(Invocation.method(#signInWithCredential, null))
            .on(mockAuth)
            .thenThrow(FirebaseAuthException(code: 'invalid-credential'));

        // Act & Assert
        await expectLater(
          () => authService.signInWithGoogle(),
          throwsA(isA<FirebaseAuthException>()),
        );

        // Verify error was logged to Crashlytics
        verify(
          mockCrashlytics.recordError(
            any,
            any,
            reason: 'Google Sign-In failed',
            information: anyNamed('information'),
            fatal: false,
          ),
        ).called(1);
      });

      test('rejects non-BU email addresses', () async {
        // Arrange
        const nonBUEmail = 'test@gmail.com';
        final mockGoogleAccount = MockGoogleSignInAccount();

        when(mockGoogleSignIn.supportsAuthenticate()).thenReturn(true);
        when(
          mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) async => mockGoogleAccount);
        when(mockGoogleAccount.email).thenReturn(nonBUEmail);
        when(
          mockGoogleSignIn.signOut(),
        ).thenAnswer((_) async => mockGoogleAccount);

        // Act & Assert
        await expectLater(
          () => authService.signInWithGoogle(),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Boston University students only'),
            ),
          ),
        );

        // Verify Google sign-out was called to clean up
        verify(mockGoogleSignIn.signOut()).called(1);
      });
    });

    group('signInWithApple', () {
      const email = 'test@bu.edu';
      const userId = 'apple-user-123';

      test('successful sign-in with new user', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(
          mockUser: MockUser(
            uid: userId,
            email: email,
            displayName: 'Test User',
            photoURL: 'https://example.com/photo.jpg',
            isAnonymous: false,
            providerData: [
              _appleUserInfo(),
            ],
          ),
        );
        authService = createAuthService(mockAuth);

        // Act
        final result = await authService.signInWithApple();

        // Assert
        expect(result, isNotNull);
        expect(result!.id, userId);
        expect(result.email, email);
        expect(result.username, 'test');
        expect(result.displayName, 'Test User');
        expect(result.authProvider, 'apple');
        expect(result.isEmailVerified, true);
        expect(result.hasCreatedProfile, false);

        // Verify user document was created
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        expect(userDoc.exists, true);
        expect(userDoc.data()?['authProvider'], 'apple');

        // Verify analytics was set
        verify(mockAnalytics.setUserId(id: userId)).called(1);
      });

      test('successful sign-in with existing user', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(
          mockUser: MockUser(
            uid: userId,
            email: email,
            isAnonymous: false,
            providerData: [
              _appleUserInfo(),
            ],
          ),
        );
        authService = createAuthService(mockAuth);

        final existingUser = UserFixtures.appleUser.copyWith(id: userId);
        await fakeFirestore
            .collection('users')
            .doc(userId)
            .set(existingUser.toMap());

        // Act
        final result = await authService.signInWithApple();

        // Assert
        expect(result, isNotNull);
        expect(result!.id, userId);

        // Verify online status was updated
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        expect(userDoc.data()?['isOnline'], true);
      });

      test('rethrows FirebaseAuthException on provider error', () async {
        // Arrange
        whenCalling(Invocation.method(#signInWithProvider, null))
            .on(mockAuth)
            .thenThrow(FirebaseAuthException(code: 'invalid-credential'));

        // Act & Assert
        await expectLater(
          () => authService.signInWithApple(),
          throwsA(isA<FirebaseAuthException>()),
        );

        // Verify error was logged to Crashlytics
        verify(
          mockCrashlytics.recordError(
            any,
            any,
            reason: 'Apple Sign-In failed',
            information: anyNamed('information'),
            fatal: false,
          ),
        ).called(1);
      });
    });

    group('signOut', () {
      const userId = 'user-123';

      test('updates online status and signs out', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: userId, isAnonymous: false),
        );
        authService = createAuthService(mockAuth);

        final user = UserFixtures.custom(id: userId, email: 'test@bu.edu');
        await fakeFirestore.collection('users').doc(userId).set(user.toMap());

        // Act
        await authService.signOut();

        // Assert
        expect(mockAuth.currentUser, isNull);

        // Verify online status was updated
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        expect(userDoc.data()?['isOnline'], false);
        expect(userDoc.data()?['lastSeen'], isNotNull);
      });

      test('signs out even when currentUser is null', () async {
        // Arrange - default mockAuth has no signed-in user

        // Act
        await authService.signOut();

        // Assert
        expect(mockAuth.currentUser, isNull);
      });

      test('rethrows exception when signOut fails', () async {
        // Arrange
        whenCalling(Invocation.method(#signOut, null))
            .on(mockAuth)
            .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

        // Act & Assert
        await expectLater(
          () => authService.signOut(),
          throwsA(isA<FirebaseAuthException>()),
        );
      });
    });

    group('getUserData', () {
      const userId = 'user-123';

      test('returns user data for existing user', () async {
        // Arrange
        final user = UserFixtures.custom(id: userId, email: 'test@bu.edu');
        await fakeFirestore.collection('users').doc(userId).set(user.toMap());

        // Act
        final result = await authService.getUserData(userId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, userId);
        expect(result.email, 'test@bu.edu');
      });

      test('returns null for non-existent user', () async {
        // Act
        final result = await authService.getUserData('non-existent-id');

        // Assert
        expect(result, isNull);
      });
    });

    group('updateUserProfile', () {
      const userId = 'user-123';

      test('updates profile fields successfully', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: userId, isAnonymous: false),
        );
        authService = createAuthService(mockAuth);

        final user = UserFixtures.custom(
          id: userId,
          email: 'test@bu.edu',
          hasCreatedProfile: false,
        );
        await fakeFirestore.collection('users').doc(userId).set(user.toMap());

        // Act
        await authService.updateUserProfile(
          displayName: 'New Name',
          bio: 'New bio',
          classYear: '2025',
          location: 'Warren Towers',
          interests: ['sports', 'music'],
        );

        // Assert
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        expect(userDoc.data()?['displayName'], 'New Name');
        expect(userDoc.data()?['bio'], 'New bio');
        expect(userDoc.data()?['classYear'], '2025');
        expect(userDoc.data()?['location'], 'Warren Towers');
        expect(userDoc.data()?['interests'], ['sports', 'music']);
        expect(userDoc.data()?['hasCreatedProfile'], true);
      });

      test('allows setting gender for first time', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: userId, isAnonymous: false),
        );
        authService = createAuthService(mockAuth);

        final user = UserFixtures.custom(
          id: userId,
          email: 'test@bu.edu',
          gender: null,
        );
        await fakeFirestore.collection('users').doc(userId).set(user.toMap());

        // Act
        await authService.updateUserProfile(gender: 'male');

        // Assert
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        expect(userDoc.data()?['gender'], 'male');
        expect(userDoc.data()?['genderChangeCount'], 0);
      });

      test('allows changing gender once', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: userId, isAnonymous: false),
        );
        authService = createAuthService(mockAuth);

        final user = UserFixtures.custom(
          id: userId,
          email: 'test@bu.edu',
          gender: 'male',
        );
        await fakeFirestore.collection('users').doc(userId).set(user.toMap());

        // Act
        await authService.updateUserProfile(gender: 'female');

        // Assert
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        expect(userDoc.data()?['gender'], 'female');
        expect(userDoc.data()?['genderChangeCount'], 1);
        expect(userDoc.data()?['genderChangedAt'], isNotNull);
      });

      test('rejects second gender change for non-whitelisted users', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: userId, isAnonymous: false),
        );
        authService = createAuthService(mockAuth);

        final user = UserModel(
          id: userId,
          email: 'test@bu.edu',
          username: 'test',
          gender: 'male',
          genderChangeCount: 1,
          createdAt: DateTime.now(),
        );
        await fakeFirestore.collection('users').doc(userId).set(user.toMap());

        // Act & Assert
        await expectLater(
          () => authService.updateUserProfile(gender: 'female'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('already changed your gender once'),
            ),
          ),
        );
      });

      test('allows unlimited gender changes for whitelisted users', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: userId, isAnonymous: false),
        );
        authService = createAuthService(mockAuth);

        final user = UserModel(
          id: userId,
          email: 'jordangr@bu.edu',
          username: 'jordangr',
          gender: 'male',
          genderChangeCount: 5,
          createdAt: DateTime.now(),
        );
        await fakeFirestore.collection('users').doc(userId).set(user.toMap());

        // Act
        await authService.updateUserProfile(gender: 'female');

        // Assert
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        expect(userDoc.data()?['gender'], 'female');
        expect(userDoc.data()?['genderChangeCount'], 6);
      });
    });

    group('isUsernameAvailable', () {
      test('returns true when username is available', () async {
        // Act
        final result = await authService.isUsernameAvailable('newusername');

        // Assert
        expect(result, true);
      });

      test('returns false when username is taken', () async {
        // Arrange
        final user = UserFixtures.custom(
          id: 'user-123',
          username: 'takenusername',
        );
        await fakeFirestore
            .collection('users')
            .doc('user-123')
            .set(user.toMap());

        // Act
        final result = await authService.isUsernameAvailable('takenusername');

        // Assert
        expect(result, false);
      });
    });

    group('reauthenticateUser', () {
      const userId = 'user-123';

      test('reauthenticates Google user successfully', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: userId, isAnonymous: false),
        );
        authService = createAuthService(mockAuth);

        final user = UserModel(
          id: userId,
          email: 'test@bu.edu',
          username: 'test',
          authProvider: 'google',
          createdAt: DateTime.now(),
        );
        await fakeFirestore.collection('users').doc(userId).set(user.toMap());

        final mockGoogleAccount = MockGoogleSignInAccount();
        final mockGoogleAuth = MockGoogleSignInAuthentication();

        when(
          mockGoogleSignIn.initialize(
            serverClientId: anyNamed('serverClientId'),
          ),
        ).thenAnswer((_) async {});
        when(
          mockGoogleSignIn.disconnect(),
        ).thenAnswer((_) => Future<GoogleSignInAccount?>.value(null));
        when(
          mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) async => mockGoogleAccount);
        when(mockGoogleAccount.authentication).thenReturn(mockGoogleAuth);
        when(mockGoogleAuth.idToken).thenReturn('fake-id-token');

        // Act
        final result = await authService.reauthenticateUser();

        // Assert
        expect(result, true);
        verify(mockGoogleSignIn.disconnect()).called(1);
        verify(mockGoogleSignIn.authenticate()).called(1);
      });

      test('reauthenticates Apple user successfully', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: userId, isAnonymous: false),
        );
        authService = createAuthService(mockAuth);

        final user = UserFixtures.appleUser.copyWith(id: userId);
        await fakeFirestore.collection('users').doc(userId).set(user.toMap());

        // Act
        final result = await authService.reauthenticateUser();

        // Assert
        expect(result, true);
      });

      test('returns false when user is not signed in', () async {
        // Arrange - default mockAuth has no signed-in user

        // Act
        final result = await authService.reauthenticateUser();

        // Assert
        expect(result, false);
      });

      test('returns false for unsupported auth provider', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: userId, isAnonymous: false),
        );
        authService = createAuthService(mockAuth);

        final user = UserModel(
          id: userId,
          email: 'test@bu.edu',
          username: 'test',
          authProvider: 'email',
          createdAt: DateTime.now(),
        );
        await fakeFirestore.collection('users').doc(userId).set(user.toMap());

        // Act
        final result = await authService.reauthenticateUser();

        // Assert
        expect(result, false);
      });

      test('returns false when user data is not found', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: userId, isAnonymous: false),
        );
        authService = createAuthService(mockAuth);
        // No user document in Firestore

        // Act
        final result = await authService.reauthenticateUser();

        // Assert
        expect(result, false);
      });
    });

    group('sendPasswordResetEmail', () {
      test('sends password reset email successfully', () async {
        // Act & Assert
        await expectLater(
          authService.sendPasswordResetEmail('test@bu.edu'),
          completes,
        );
      });

      test('rethrows exception on failure', () async {
        // Arrange
        whenCalling(Invocation.method(#sendPasswordResetEmail, null))
            .on(mockAuth)
            .thenThrow(FirebaseAuthException(code: 'user-not-found'));

        // Act & Assert
        await expectLater(
          () => authService.sendPasswordResetEmail('test@bu.edu'),
          throwsA(isA<FirebaseAuthException>()),
        );
      });
    });
  });
}
