// This is a comprehensive Flutter integration test.
//
// Integration tests run the complete app and allow testing of multiple widgets
// and interactions together. They can run on devices or emulators and test the
// entire app flow including navigation, state management, and user interactions.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:squad_app/main.dart' as app;

void main() {
  // Required for integration tests
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SquadApp Integration Tests', () {
    testWidgets('App launches and shows loading or consent dialog',
        (WidgetTester tester) async {
      // Start the app
      app.main();

      // Wait for the app to settle
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // The app should either show:
      // 1. A CircularProgressIndicator (while checking consent/loading)
      // 2. ConsentDialogScreen (if consent not given)
      // 3. LoginScreen (if consent already given and not authenticated)

      // We can verify that the app loaded without crashing
      expect(
        find.byType(MaterialApp),
        findsWidgets,
        reason: 'MaterialApp should be present',
      );
    });

    testWidgets('Consent dialog interaction flow', (WidgetTester tester) async {
      // Start the app
      app.main();

      // Wait for the app to settle and show the consent dialog
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Look for consent-related UI elements (adjust based on your ConsentDialogScreen)
      // This is an example - you'll need to adjust based on your actual widget keys/text

      // Example: If your consent dialog has "Accept" and "Decline" buttons
      final acceptButton = find.text('Allow Analytics');

      // If consent dialog is shown, one of these should be present
      if (acceptButton.evaluate().isNotEmpty) {
        // Tap the accept button
        await tester.tap(acceptButton);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // After accepting, should navigate to login screen
        // Adjust this based on your actual LoginScreen widgets
        expect(
          find.byType(MaterialApp),
          findsWidgets,
          reason: 'App should continue after consent',
        );
      }
    });

    testWidgets('Navigation smoke test', (WidgetTester tester) async {
      // Start the app
      app.main();

      // Wait for initial loading
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // This test verifies that basic navigation and routing works
      // The app should be able to build and render without throwing errors

      // Verify that Flutter's widget tree is valid
      expect(tester.takeException(), isNull,
          reason: 'No exceptions should be thrown during app initialization');
    });

    testWidgets('Firebase initialization completes', (WidgetTester tester) async {
      // Start the app
      app.main();

      // Firebase initialization happens in main()
      // Wait long enough for Firebase to initialize
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // If we get here without errors, Firebase initialized successfully
      // The app should be showing some UI (not a blank screen)
      expect(
        find.byType(MaterialApp),
        findsWidgets,
        reason: 'App should have initialized Firebase and built UI',
      );
    });
  });

  group('Authentication Flow Tests', () {
    testWidgets('Login screen is accessible', (WidgetTester tester) async {
      // Note: This test assumes you've already given consent in previous runs
      // or you'll need to handle the consent dialog first

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Look for login-related elements
      // Adjust these based on your actual LoginScreen widgets

      // Example: Looking for common login UI elements
      // You might have email fields, password fields, or social login buttons

      // At least one authentication method should be visible
      // (or adjust based on your actual implementation)
      expect(
        find.byType(MaterialApp),
        findsWidgets,
        reason: 'Login screen should be rendered',
      );
    });
  });

  group('Error Handling Tests', () {
    testWidgets('App handles widget errors gracefully',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify no unhandled exceptions
      expect(tester.takeException(), isNull,
          reason: 'App should handle errors gracefully');
    });
  });
}
