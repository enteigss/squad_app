import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Full Authentication Flow', () {
    setUpAll(() async {
      await setupFirebaseEmulators();
    });

    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Sign out any existing user
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('No user to sign out: $e');
      }
    });

    tearDown(() async {
      // Clean up test user data from Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await cleanupTestUser(user.uid);
        // Also clean up any email verification documents
        try {
          await FirebaseFirestore.instance
              .collection('email_verifications')
              .doc(user.uid)
              .delete();
        } catch (e) {
          debugPrint('⚠️ No email verification doc to clean up: $e');
        }
      }

      // Sign out
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('⚠️ Failed to sign out in tearDown: $e');
      }
    });

    group('New User Journey', () {
      testWidgets(
        'new user completes full flow: login → sign-in → profile setup → home',
        (WidgetTester tester) async {
          // Start the app
          app.main();
          await tester.pumpAndSettle(const Duration(seconds: 5));

          // STEP 1: Handle Analytics Consent
          debugPrint('🧪 TEST: Looking for consent dialog...');
          await handleAnalyticsConsent(tester);
          await tester.pumpAndSettle(const Duration(seconds: 3));

          // STEP 2: Verify Login Screen UI
          debugPrint('🧪 TEST: Verifying login screen...');
          expect(
            find.text('Sign in with BU Google Account'),
            findsOneWidget,
            reason: 'Google sign-in button should be visible',
          );
          expect(
            find.text('Sign in with Apple'),
            findsOneWidget,
            reason: 'Apple sign-in button should be visible',
          );
          expect(
            find.text('Exclusive to BU Students'),
            findsOneWidget,
            reason: 'BU info card should be visible',
          );
          debugPrint('✅ Login screen UI verified');

          // STEP 3: Sign in with test user
          debugPrint('🧪 TEST: Signing in test user...');
          await signInTestUser('newuser@bu.edu', 'TestPassword123!');
          await tester.pumpAndSettle(const Duration(seconds: 5));
          debugPrint('✅ Test user signed in');

          // STEP 4: Verify navigated to profile setup
          debugPrint('🧪 TEST: Verifying profile setup screen...');
          expect(
            find.text('Complete Your Profile'),
            findsOneWidget,
            reason: 'Profile setup screen should be visible',
          );
          debugPrint('✅ Profile setup screen visible');

          // STEP 5: Complete profile setup
          debugPrint('🧪 TEST: Completing profile setup...');
          await completeProfileSetup(
            tester,
            name: 'Test User',
            classYear: 'Sophomore',
            dorm: 'Warren Towers',
            gender: 'Man',
            interests: ['Basketball', 'Gaming'],
          );
          await tester.pumpAndSettle(const Duration(seconds: 5));

          // STEP 6: Handle welcome popup
          debugPrint('🧪 TEST: Looking for welcome popup...');
          final letsGoButton = find.text("Let's Go!");
          if (letsGoButton.evaluate().isNotEmpty) {
            await tester.tap(letsGoButton);
            await tester.pumpAndSettle(const Duration(seconds: 3));
            debugPrint('✅ Welcome popup dismissed');
          }

          // STEP 7: Verify on main screen (look for bottom navigation)
          debugPrint('🧪 TEST: Verifying main screen...');
          expect(
            find.byType(BottomNavigationBar),
            findsOneWidget,
            reason: 'Should be on main screen with bottom navigation',
          );
          debugPrint('✅ Main screen visible');

          // STEP 8: Verify Firestore user document was created
          debugPrint('🧪 TEST: Verifying Firestore document...');
          final uid = FirebaseAuth.instance.currentUser!.uid;
          await verifyUserDocument(uid);
          debugPrint('✅ Firestore document verified');

          debugPrint('✅ TEST: New user journey completed successfully!');
        },
      );
    });

    group('Email Verification Flow', () {
      testWidgets(
        'unverified user completes email verification → profile setup → home',
        (WidgetTester tester) async {
          // SETUP: Create user with isEmailVerified: false (simulates Apple Sign In
          // where BU email was not detected)
          debugPrint('🧪 TEST: Creating unverified user...');
          final cred = await signInUnverifiedTestUser(
            'unverified@gmail.com',
            'TestPassword123!',
          );
          final uid = cred.user!.uid;
          await FirebaseAuth.instance.signOut();
          debugPrint('✅ Unverified user created (uid: $uid)');

          // Start the app
          app.main();
          await tester.pumpAndSettle(const Duration(seconds: 5));

          // STEP 1: Handle Analytics Consent
          debugPrint('🧪 TEST: Handling consent...');
          await handleAnalyticsConsent(tester);
          await tester.pumpAndSettle(const Duration(seconds: 3));

          // STEP 2: Sign in (triggers auth state change → redirect to email verification)
          debugPrint('🧪 TEST: Signing in unverified user...');
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: 'unverified@gmail.com',
            password: 'TestPassword123!',
          );
          await tester.pumpAndSettle(const Duration(seconds: 5));

          // STEP 3: Verify on email verification screen
          debugPrint('🧪 TEST: Verifying email verification screen...');
          expect(
            find.text('Verify Your BU Email'),
            findsOneWidget,
            reason: 'Should be on email verification screen',
          );
          debugPrint('✅ Email verification screen visible');

          // STEP 4: Enter BU email address
          debugPrint('🧪 TEST: Entering BU email...');
          final emailField = find.byType(TextFormField).first;
          await tester.enterText(emailField, 'testuser@bu.edu');
          await tester.pumpAndSettle();
          debugPrint('✅ Entered BU email');

          // STEP 5: Tap "Send Verification Code"
          debugPrint('🧪 TEST: Sending verification code...');
          final sendButton = find.text('Send Verification Code');
          expect(
            sendButton,
            findsOneWidget,
            reason: 'Send Verification Code button should be visible',
          );
          await tester.tap(sendButton);
          await tester.pumpAndSettle(const Duration(seconds: 5));
          debugPrint('✅ Verification code sent');

          // STEP 6: Read the verification code from Firestore
          // (the Cloud Function stored it there — in emulator mode it skips
          // the actual email send but still generates and stores the code)
          debugPrint('🧪 TEST: Reading verification code from Firestore...');
          final code = await getVerificationCodeFromFirestore(uid);
          debugPrint('✅ Got verification code: $code');

          // STEP 7: Enter the verification code
          debugPrint('🧪 TEST: Entering verification code...');
          final codeField = find.byType(TextFormField).last;
          await tester.enterText(codeField, code);
          await tester.pumpAndSettle(const Duration(seconds: 5));
          debugPrint('✅ Verification code entered');

          // STEP 8: Verify redirected to profile setup
          // (validateVerificationCode updates isEmailVerified in Firestore,
          // then AuthProvider.refreshCurrentUser() fires, GoRouter redirects)
          debugPrint('🧪 TEST: Verifying redirect to profile setup...');
          await tester.pumpAndSettle(const Duration(seconds: 5));
          expect(
            find.text('Complete Your Profile'),
            findsOneWidget,
            reason: 'Should be on profile setup after email verification',
          );
          debugPrint('✅ Profile setup screen visible');

          // STEP 9: Complete profile setup
          debugPrint('🧪 TEST: Completing profile setup...');
          await completeProfileSetup(
            tester,
            name: 'Verified User',
            classYear: 'Junior',
            dorm: 'Warren Towers',
            gender: 'Woman',
            interests: ['Music'],
          );
          await tester.pumpAndSettle(const Duration(seconds: 5));

          // STEP 10: Handle welcome popup
          final letsGoButton = find.text("Let's Go!");
          if (letsGoButton.evaluate().isNotEmpty) {
            await tester.tap(letsGoButton);
            await tester.pumpAndSettle(const Duration(seconds: 3));
          }

          // STEP 11: Verify on main screen
          debugPrint('🧪 TEST: Verifying main screen...');
          expect(
            find.byType(BottomNavigationBar),
            findsOneWidget,
            reason: 'Should be on main screen after completing full flow',
          );

          // STEP 12: Verify Firestore user document has isEmailVerified: true
          debugPrint('🧪 TEST: Verifying email verified in Firestore...');
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          expect(
            userDoc.data()?['isEmailVerified'],
            isTrue,
            reason: 'User should be email verified in Firestore',
          );
          expect(
            userDoc.data()?['verifiedEmail'],
            equals('testuser@bu.edu'),
            reason: 'Verified email should be stored',
          );

          debugPrint(
              '✅ TEST: Email verification flow completed successfully!');
        },
      );
    });

    group('Returning User Journey', () {
      testWidgets(
        'returning user with completed profile skips profile setup',
        (WidgetTester tester) async {
          // Pre-create user with completed profile
          debugPrint('🧪 TEST: Setting up returning user...');
          final cred = await signInTestUser(
            'returning@bu.edu',
            'TestPassword123!',
          );
          await createCompletedUserProfile(cred.user!.uid, 'returning@bu.edu');
          await FirebaseAuth.instance.signOut();
          debugPrint('✅ Returning user setup complete');

          // Start the app
          app.main();
          await tester.pumpAndSettle(const Duration(seconds: 5));

          // Handle consent
          await handleAnalyticsConsent(tester);
          await tester.pumpAndSettle(const Duration(seconds: 3));

          // Sign in again
          debugPrint('🧪 TEST: Signing in returning user...');
          await signInTestUser('returning@bu.edu', 'TestPassword123!');
          await tester.pumpAndSettle(const Duration(seconds: 5));

          // Should skip profile setup and go directly to main
          debugPrint('🧪 TEST: Verifying profile setup is skipped...');
          expect(
            find.text('Complete Your Profile'),
            findsNothing,
            reason: 'Should skip profile setup for returning user',
          );

          // Should be on main screen
          expect(
            find.byType(BottomNavigationBar),
            findsOneWidget,
            reason: 'Should be on main screen',
          );

          debugPrint('✅ TEST: Returning user journey completed successfully!');
        },
      );
    });

    group('Sign Out Flow', () {
      testWidgets(
        'sign out clears auth and returns to login screen',
        (WidgetTester tester) async {
          // Pre-create user with completed profile
          debugPrint('🧪 TEST: Setting up user for sign out test...');
          final cred = await signInTestUser(
            'signout@bu.edu',
            'TestPassword123!',
          );
          await createCompletedUserProfile(cred.user!.uid, 'signout@bu.edu');
          await FirebaseAuth.instance.signOut();

          // Start the app
          app.main();
          await tester.pumpAndSettle(const Duration(seconds: 5));

          // Handle consent
          await handleAnalyticsConsent(tester);
          await tester.pumpAndSettle(const Duration(seconds: 3));

          // Sign in
          await signInTestUser('signout@bu.edu', 'TestPassword123!');
          await tester.pumpAndSettle(const Duration(seconds: 5));

          // Verify on main screen
          expect(find.byType(BottomNavigationBar), findsOneWidget);
          debugPrint('✅ User signed in and on main screen');

          // Navigate to profile tab (usually last tab)
          debugPrint('🧪 TEST: Navigating to profile...');
          final profileIcon = find.byIcon(Icons.person);
          if (profileIcon.evaluate().isNotEmpty) {
            await tester.tap(profileIcon.last);
            await tester.pumpAndSettle(const Duration(seconds: 2));
          }

          // Look for sign out button and tap it
          debugPrint('🧪 TEST: Looking for sign out button...');
          await signOut(tester);
          await tester.pumpAndSettle(const Duration(seconds: 5));

          // Verify back on login screen
          debugPrint('🧪 TEST: Verifying return to login screen...');
          expect(
            find.text('Sign in with BU Google Account'),
            findsOneWidget,
            reason: 'Should be back on login screen after sign out',
          );

          // Verify Firebase auth state is cleared
          expect(
            FirebaseAuth.instance.currentUser,
            isNull,
            reason: 'Firebase user should be null after sign out',
          );

          debugPrint('✅ TEST: Sign out flow completed successfully!');
        },
      );
    });

    group('Login Screen UI', () {
      testWidgets(
        'login screen displays all required elements',
        (WidgetTester tester) async {
          // Start the app
          app.main();
          await tester.pumpAndSettle(const Duration(seconds: 5));

          // Handle consent
          await handleAnalyticsConsent(tester);
          await tester.pumpAndSettle(const Duration(seconds: 3));

          // Verify all UI elements
          expect(find.text('LinkUp BU'), findsOneWidget);
          expect(find.text('Boston University Students Only'), findsOneWidget);
          expect(find.text('Sign in with BU Google Account'), findsOneWidget);
          expect(find.text('Sign in with Apple'), findsOneWidget);
          expect(find.text('Exclusive to BU Students'), findsOneWidget);
          expect(find.text('Need help?'), findsOneWidget);
          expect(find.text('Privacy Policy'), findsOneWidget);

          debugPrint('✅ TEST: All login screen elements verified');
        },
      );
    });
  });
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Configure Firebase emulators for testing
Future<void> setupFirebaseEmulators() async {
  await Firebase.initializeApp();

  // Use 10.0.2.2 for Android emulator (maps to host's localhost)
  // Use 127.0.0.1 for iOS simulator, desktop, or physical devices on same network
  final emulatorHost = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';

  // Connect to Firebase Auth Emulator
  try {
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    debugPrint('🔧 Connected to Firebase Auth Emulator on $emulatorHost:9099');
  } catch (e) {
    debugPrint('⚠️ Failed to connect to Auth Emulator: $e');
  }

  // Connect to Firestore Emulator
  try {
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    debugPrint('🔧 Connected to Firestore Emulator on $emulatorHost:8080');
  } catch (e) {
    debugPrint('⚠️ Failed to connect to Firestore Emulator: $e');
  }

  // Connect to Cloud Functions Emulator
  try {
    FirebaseFunctions.instance.useFunctionsEmulator(emulatorHost, 5001);
    debugPrint(
        '🔧 Connected to Functions Emulator on $emulatorHost:5001');
  } catch (e) {
    debugPrint('⚠️ Failed to connect to Functions Emulator: $e');
  }
}

/// Handle the analytics consent dialog
Future<void> handleAnalyticsConsent(WidgetTester tester) async {
  final allowButton = find.text('Allow Analytics');

  if (allowButton.evaluate().isNotEmpty) {
    expect(
      allowButton,
      findsOneWidget,
      reason: 'Allow Analytics button should be visible',
    );

    await tester.tap(allowButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    debugPrint('✅ Analytics consent granted');
  } else {
    debugPrint('ℹ️ No consent dialog found, skipping...');
  }
}

/// Sign in with test credentials via Firebase Auth emulator.
/// Creates the Firestore user document immediately after creating the Auth user
/// so that the AuthProvider's listener can always find the document.
Future<UserCredential> signInTestUser(String email, String password) async {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  // Try to sign in first (user may already exist from a previous test)
  try {
    final cred = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    debugPrint('✅ Signed in existing user: $email');

    // Ensure Firestore doc exists
    final uid = cred.user!.uid;
    final userDoc = await firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      await firestore.collection('users').doc(uid).set({
        'id': uid,
        'email': email,
        'username': email.split('@')[0],
        'displayName': null,
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'hasCreatedProfile': false,
        'authProvider': 'email',
        'isEmailVerified': true,
      });
      debugPrint('✅ Created missing Firestore doc for existing user: $email');
    }

    return cred;
  } catch (e) {
    debugPrint('ℹ️ User does not exist, creating: $email');
  }

  // User doesn't exist — create Auth user AND Firestore doc immediately
  // (so the AuthProvider's listener can find the doc when auth state fires)
  final cred = await auth.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
  final uid = cred.user!.uid;

  await firestore.collection('users').doc(uid).set({
    'id': uid,
    'email': email,
    'username': email.split('@')[0],
    'displayName': null,
    'photoUrl': null,
    'createdAt': FieldValue.serverTimestamp(),
    'isOnline': true,
    'hasCreatedProfile': false,
    'authProvider': 'email',
    'isEmailVerified': true,
  });
  debugPrint('✅ Created new user + Firestore doc: $email (uid: $uid)');

  return cred;
}

/// Complete profile setup form with test data
Future<void> completeProfileSetup(
  WidgetTester tester, {
  required String name,
  required String classYear,
  required String dorm,
  required String gender,
  List<String> interests = const [],
}) async {
  // Wait for profile setup screen to fully load
  await tester.pumpAndSettle(const Duration(seconds: 2));

  // Fill in Full Name
  final nameField = find.byType(TextFormField).first;
  await tester.enterText(nameField, name);
  await tester.pumpAndSettle();
  debugPrint('✅ Entered full name: $name');

  // Select Class Year from dropdown
  final classYearDropdown = find.byType(DropdownButtonFormField<String>).first;
  await tester.tap(classYearDropdown);
  await tester.pumpAndSettle();

  final classYearOption = find.text(classYear).last;
  await tester.tap(classYearOption);
  await tester.pumpAndSettle();
  debugPrint('✅ Selected class year: $classYear');

  // Select Location (dorm) from dropdown
  final locationDropdown = find.byType(DropdownButtonFormField<String>).last;
  await tester.tap(locationDropdown);
  await tester.pumpAndSettle();

  final dormOption = find.text(dorm).last;
  await tester.tap(dormOption);
  await tester.pumpAndSettle();
  debugPrint('✅ Selected location: $dorm');

  // Add interests if provided
  for (final interest in interests) {
    // Try to find a popular interest chip first
    final interestChip = find.text(interest);
    if (interestChip.evaluate().isNotEmpty) {
      await tester.tap(interestChip.first);
      await tester.pumpAndSettle();
      debugPrint('✅ Added interest: $interest');
    }
  }

  // Scroll down to see gender options
  await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
  await tester.pumpAndSettle();

  // Select gender identity
  final genderOption = find.text(gender);
  if (genderOption.evaluate().isNotEmpty) {
    await tester.tap(genderOption);
    await tester.pumpAndSettle();
    debugPrint('✅ Selected gender: $gender');
  }

  // Scroll down to see the Complete Profile button
  await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
  await tester.pumpAndSettle();

  // Tap Complete Profile button
  final completeButton = find.text('Complete Profile');
  expect(
    completeButton,
    findsOneWidget,
    reason: 'Complete Profile button should be visible',
  );

  await tester.tap(completeButton);
  await tester.pumpAndSettle(const Duration(seconds: 5));
  debugPrint('✅ Profile setup completed');
}

/// Navigate to settings and sign out
Future<void> signOut(WidgetTester tester) async {
  // Look for sign out button - might need to scroll
  final signOutButton = find.text('Sign Out');

  if (signOutButton.evaluate().isEmpty) {
    // Try scrolling to find it
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
  }

  if (signOutButton.evaluate().isNotEmpty) {
    await tester.tap(signOutButton.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Handle confirmation dialog if present
    final confirmSignOut = find.text('Sign Out');
    if (confirmSignOut.evaluate().length > 1) {
      await tester.tap(confirmSignOut.last);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }
    debugPrint('✅ Sign out completed');
  } else {
    // Fallback: sign out directly via Firebase
    await FirebaseAuth.instance.signOut();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    debugPrint('✅ Sign out completed (via Firebase directly)');
  }
}

/// Verify user document exists in Firestore
Future<void> verifyUserDocument(String uid) async {
  final doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();

  expect(doc.exists, isTrue, reason: 'User document should exist in Firestore');
  debugPrint('✅ User document exists: ${doc.data()}');
}

/// Create a completed user profile in Firestore (for returning user tests)
Future<void> createCompletedUserProfile(String uid, String email) async {
  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'id': uid,
    'email': email,
    'username': email.split('@')[0],
    'displayName': 'Test Returning User',
    'classYear': 'Junior',
    'location': 'Warren Towers',
    'gender': 'man',
    'interests': ['Sports', 'Music'],
    'bio': 'Test bio',
    'hasCreatedProfile': true,
    'isEmailVerified': true,
    'authProvider': 'email',
    'isOnline': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
  debugPrint('✅ Created completed user profile for: $email');
}

/// Sign in a test user with isEmailVerified: false (simulates Apple Sign In).
/// Creates the Auth user and Firestore doc immediately so the AuthProvider
/// always finds the document when the auth state listener fires.
Future<UserCredential> signInUnverifiedTestUser(
    String email, String password) async {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  // Try to sign in first (user may already exist)
  try {
    final cred = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;

    // Overwrite Firestore doc to ensure isEmailVerified: false
    await firestore.collection('users').doc(uid).set({
      'id': uid,
      'email': email,
      'username': email.split('@')[0],
      'displayName': null,
      'photoUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
      'isOnline': true,
      'hasCreatedProfile': false,
      'authProvider': 'apple',
      'isEmailVerified': false,
    });
    debugPrint('✅ Signed in existing unverified user: $email');
    return cred;
  } catch (e) {
    debugPrint('ℹ️ User does not exist, creating unverified user: $email');
  }

  // User doesn't exist — create Auth user AND Firestore doc immediately
  final cred = await auth.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
  final uid = cred.user!.uid;

  await firestore.collection('users').doc(uid).set({
    'id': uid,
    'email': email,
    'username': email.split('@')[0],
    'displayName': null,
    'photoUrl': null,
    'createdAt': FieldValue.serverTimestamp(),
    'isOnline': true,
    'hasCreatedProfile': false,
    'authProvider': 'apple',
    'isEmailVerified': false,
  });
  debugPrint('✅ Created new unverified user + Firestore doc: $email (uid: $uid)');

  return cred;
}

/// Read the verification code from Firestore (for testing only).
/// The Cloud Function stores the code in the email_verifications collection.
Future<String> getVerificationCodeFromFirestore(String uid) async {
  final doc = await FirebaseFirestore.instance
      .collection('email_verifications')
      .doc(uid)
      .get();

  expect(
    doc.exists,
    isTrue,
    reason: 'Verification document should exist in Firestore after sending code',
  );

  final code = doc.data()!['code'] as String;
  debugPrint('🔑 Retrieved verification code from Firestore: $code');
  return code;
}

/// Clean up test user from Firestore
Future<void> cleanupTestUser(String uid) async {
  try {
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    debugPrint('✅ Cleaned up test user: $uid');
  } catch (e) {
    debugPrint('⚠️ Failed to cleanup test user: $e');
  }
}
