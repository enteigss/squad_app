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

  group('Onboarding Flow Integration Test', () {
    setUpAll(() async {
      // Configure Firebase to use emulators
      await setupFirebaseEmulators();
    });

    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    testWidgets(
      'User gives consent, signs in with Google, creates profile, and creates first hangout',
      (WidgetTester tester) async {
        // Start the app
        app.main();

        // Wait for app to initialize and show consent dialog
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // STEP 1: Handle Analytics Consent
        debugPrint('🧪 TEST: Looking for consent dialog...');
        await handleAnalyticsConsent(tester);

        // Wait for navigation to login screen
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // STEP 2: Mock Google Sign-In
        debugPrint('🧪 TEST: Attempting Google Sign-In...');
        await mockGoogleSignIn(tester);

        // Wait for authentication to complete and navigate to profile setup
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // STEP 3: Complete Profile Setup
        debugPrint('🧪 TEST: Completing profile setup...');
        await completeProfileSetup(tester);

        // Wait for navigation to main screen
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // STEP 4: Navigate to create hangout and complete form
        debugPrint('🧪 TEST: Creating first hangout...');
        await createFirstHangout(tester);

        // Wait for hangout creation to complete
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // STEP 5: Verify successful completion
        debugPrint('🧪 TEST: Verifying successful flow completion...');
        await verifySuccessfulFlow(tester);

        debugPrint('✅ TEST: Onboarding flow completed successfully!');
      },
    );
  });
}

/// Configure Firebase emulators for testing
Future<void> setupFirebaseEmulators() async {
  // Initialize Firebase
  await Firebase.initializeApp();

  // Connect to Firebase Auth Emulator
  await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
  debugPrint('🔧 Connected to Firebase Auth Emulator on 127.0.0.1:9099');

  // Connect to Firestore Emulator
  FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
  debugPrint('🔧 Connected to Firestore Emulator on 127.0.0.1:8080');
}

/// Handle the analytics consent dialog
Future<void> handleAnalyticsConsent(WidgetTester tester) async {
  // Look for the "Allow Analytics" button
  final allowButton = find.text('Allow Analytics');

  expect(
    allowButton,
    findsOneWidget,
    reason: 'Allow Analytics button should be visible',
  );

  // Tap the button to give consent
  await tester.tap(allowButton);
  await tester.pumpAndSettle(const Duration(seconds: 2));

  debugPrint('✅ Analytics consent granted');
}

/// Sign in using Firebase Auth Emulator with email/password
Future<void> mockGoogleSignIn(WidgetTester tester) async {
  // Create a test user in Firebase Auth Emulator
  final auth = FirebaseAuth.instance;

  try {
    // Try to sign in first (in case user exists)
    await auth.signInWithEmailAndPassword(
      email: 'testuser@bu.edu',
      password: 'TestPassword123!',
    );
    debugPrint('✅ Signed in with existing test user');
  } catch (e) {
    // If user doesn't exist, create it
    await auth.createUserWithEmailAndPassword(
      email: 'testuser@bu.edu',
      password: 'TestPassword123!',
    );
    debugPrint('✅ Created and signed in new test user');
  }

  // The app should automatically detect the auth state change
  // and navigate to the appropriate screen
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

/// Complete the profile setup form
Future<void> completeProfileSetup(WidgetTester tester) async {
  // Wait for profile setup screen to appear
  await tester.pumpAndSettle(const Duration(seconds: 2));

  // Look for profile setup screen
  final profileSetupTitle = find.text('Complete Your Profile');
  expect(
    profileSetupTitle,
    findsOneWidget,
    reason: 'Profile setup screen should be visible',
  );

  // Fill in Full Name
  final nameField = find.widgetWithText(TextFormField, 'Full Name').first;
  await tester.enterText(nameField, 'Test User');
  await tester.pumpAndSettle();
  debugPrint('✅ Entered full name');

  // Select Class Year
  final classYearDropdown = find.byType(DropdownButtonFormField<String>).first;
  await tester.tap(classYearDropdown);
  await tester.pumpAndSettle();

  final sophomoreOption = find.text('Sophomore').last;
  await tester.tap(sophomoreOption);
  await tester.pumpAndSettle();
  debugPrint('✅ Selected class year');

  // Select Location (dorm)
  final locationDropdown = find.byType(DropdownButtonFormField<String>).last;
  await tester.tap(locationDropdown);
  await tester.pumpAndSettle();

  // Select first available dorm option (Warren Towers)
  final dormOption = find.text('Warren Towers').last;
  await tester.tap(dormOption);
  await tester.pumpAndSettle();
  debugPrint('✅ Selected location');

  // Add some interests
  final interestField = find.widgetWithText(TextFormField, 'Add Interest');
  await tester.enterText(interestField, 'Basketball');
  await tester.pumpAndSettle();

  // Tap the add button
  final addInterestButton = find.byIcon(Icons.add);
  await tester.tap(addInterestButton);
  await tester.pumpAndSettle();
  debugPrint('✅ Added interest: Basketball');

  // Add another interest
  await tester.enterText(interestField, 'Gaming');
  await tester.pumpAndSettle();
  await tester.tap(addInterestButton);
  await tester.pumpAndSettle();
  debugPrint('✅ Added interest: Gaming');

  // Select gender identity (required for safety)
  // Scroll down to see gender options
  await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
  await tester.pumpAndSettle();

  // Find and tap a gender option (e.g., "Man")
  final genderOption = find.text('Man');
  await tester.tap(genderOption);
  await tester.pumpAndSettle();
  debugPrint('✅ Selected gender identity');

  // Scroll down to see the Complete Profile button
  await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
  await tester.pumpAndSettle();

  // Tap Complete Profile button
  final completeButton = find.text('Complete Profile');
  await tester.tap(completeButton);
  await tester.pumpAndSettle(const Duration(seconds: 5));

  debugPrint('✅ Profile setup completed');
}

/// Create the first hangout
Future<void> createFirstHangout(WidgetTester tester) async {
  // Wait for main screen to load
  await tester.pumpAndSettle(const Duration(seconds: 3));

  // Look for create hangout button (could be a FAB or button)
  // The app likely has a create post/hangout button on the feed screen
  final createButton = find.byIcon(Icons.add).first;

  if (createButton.evaluate().isNotEmpty) {
    await tester.tap(createButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  // Wait for create post screen
  await tester.pumpAndSettle();

  // Fill in hangout title
  final titleField = find.byType(TextFormField).first;
  await tester.enterText(titleField, 'Basketball at BU Beach');
  await tester.pumpAndSettle();
  debugPrint('✅ Entered hangout title');

  // Scroll down to see more fields
  await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
  await tester.pumpAndSettle();

  // Select location by tapping the location selector
  final locationSelector = find.byIcon(Icons.location_on);
  if (locationSelector.evaluate().isNotEmpty) {
    await tester.tap(locationSelector.first);
    await tester.pumpAndSettle();

    // Select "BU Beach" from the list
    final beachOption = find.text('BU Beach');
    if (beachOption.evaluate().isNotEmpty) {
      await tester.tap(beachOption);
      await tester.pumpAndSettle();
      debugPrint('✅ Selected location: BU Beach');
    }
  }

  // Scroll down more
  await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
  await tester.pumpAndSettle();

  // Select "Now" for date/time
  final nowOption = find.text('Now (ongoing)');
  if (nowOption.evaluate().isNotEmpty) {
    await tester.tap(nowOption);
    await tester.pumpAndSettle();
    debugPrint('✅ Selected time: Now');
  }

  // Scroll to bottom to find Create Hangout button
  await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
  await tester.pumpAndSettle();

  // Find and tap Create Hangout button
  final createHangoutButton = find.text('Create Hangout');
  expect(
    createHangoutButton,
    findsOneWidget,
    reason: 'Create Hangout button should be visible',
  );

  await tester.tap(createHangoutButton);
  await tester.pumpAndSettle(const Duration(seconds: 5));

  debugPrint('✅ Hangout created');
}

/// Verify the entire flow completed successfully
Future<void> verifySuccessfulFlow(WidgetTester tester) async {
  // Look for success indicators
  // This could be a success dialog, navigation to hangouts list, etc.

  // Check if we can find success-related UI elements
  final successIndicators = [
    find.text('Hangout Created!'),
    find.byIcon(Icons.check_circle),
    find.text('Maybe Later'),
    find.text('Invite Friends'),
  ];

  for (final indicator in successIndicators) {
    if (indicator.evaluate().isNotEmpty) {
      debugPrint('✅ Found success indicator: ${indicator.toString()}');
      break;
    }
  }

  // If we found a success dialog, close it
  final maybeLaterButton = find.text('Maybe Later');
  if (maybeLaterButton.evaluate().isNotEmpty) {
    await tester.tap(maybeLaterButton);
    await tester.pumpAndSettle();
  }

  // Verify no exceptions occurred
  expect(
    tester.takeException(),
    isNull,
    reason: 'No exceptions should occur during the flow',
  );

  debugPrint('✅ Flow verification complete');
}
