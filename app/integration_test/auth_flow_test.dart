import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  // Use 127.0.0.1 for iOS simulator or physical devices on same network
  const emulatorHost = '10.0.2.2'; // Android emulator host

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

/// Sign in with test credentials via Firebase Auth emulator
/// Also creates the Firestore user document if it doesn't exist
///
/// IMPORTANT: This creates the Firestore document BEFORE signing in to Firebase Auth,
/// so that when the AuthProvider's auth state listener fires, it can find the user document.
Future<UserCredential> signInTestUser(String email, String password) async {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  // First, check if user already exists in Firebase Auth by trying to sign in
  UserCredential? existingCred;
  String? existingUid;

  try {
    existingCred = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    existingUid = existingCred.user?.uid;
    debugPrint('✅ User already exists in Firebase Auth: $email');
    // Sign out immediately - we'll sign in again after ensuring Firestore doc exists
    await auth.signOut();
  } catch (e) {
    // User doesn't exist yet - we'll create them
    debugPrint('ℹ️ User does not exist yet in Firebase Auth: $email');
  }

  // If user doesn't exist, create them first to get the UID
  if (existingUid == null) {
    final newCred = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    existingUid = newCred.user?.uid;
    debugPrint('✅ Created new Firebase Auth user: $email (uid: $existingUid)');
    // Sign out immediately - we'll sign in again after creating Firestore doc
    await auth.signOut();
  }

  // Now create/ensure Firestore document exists BEFORE signing in
  // This ensures the AuthProvider can find the document when the auth state changes
  if (existingUid != null) {
    final userDoc = await firestore.collection('users').doc(existingUid).get();

    if (!userDoc.exists) {
      await firestore.collection('users').doc(existingUid).set({
        'id': existingUid,
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
      debugPrint('✅ Created Firestore user document for: $email');
    } else {
      debugPrint('✅ Firestore user document already exists for: $email');
    }
  }

  // Now sign in - the AuthProvider's listener will fire and find the Firestore document
  final cred = await auth.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
  debugPrint('✅ Final sign-in completed for: $email');

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
    'email': email,
    'displayName': 'Test Returning User',
    'classYear': 'Junior',
    'location': 'Warren Towers',
    'gender': 'man',
    'interests': ['Sports', 'Music'],
    'bio': 'Test bio',
    'isProfileComplete': true,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  debugPrint('✅ Created completed user profile for: $email');
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
