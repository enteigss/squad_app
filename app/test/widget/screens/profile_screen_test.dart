import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_app/providers/auth_provider.dart';
import 'package:squad_app/providers/post_provider.dart';
import 'package:squad_app/screens/profile/profile_screen.dart';

import '../../fixtures/user_fixtures.dart';
import '../../helpers/firebase_test_helpers.dart';
import '../../helpers/pump_app.dart';

@GenerateNiceMocks([MockSpec<AuthProvider>(), MockSpec<PostProvider>()])
import 'profile_screen_test.mocks.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  late MockAuthProvider mockAuth;
  late MockPostProvider mockPostProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    mockAuth = MockAuthProvider();
    mockPostProvider = MockPostProvider();

    // Default stubs
    when(mockAuth.currentUser).thenReturn(UserFixtures.basicUser);
    when(mockAuth.isLoading).thenReturn(false);
    when(mockAuth.signOut()).thenAnswer((_) async {});
  });

  Future<void> pumpProfileScreen(WidgetTester tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpApp(
        const ProfileScreen(),
        authProvider: mockAuth,
        postProvider: mockPostProvider,
      );
      await tester.pump(); // Allow initState async ops to start
    });
  }

  // ── Displays User Info ─────────────────────────────────────────────

  group('displays user info', () {
    testWidgets('displays user display name', (tester) async {
      await pumpProfileScreen(tester);

      expect(find.text('Test User'), findsOneWidget);
    });

    testWidgets('displays username with @ prefix', (tester) async {
      await pumpProfileScreen(tester);

      expect(find.text('@testuser'), findsOneWidget);
    });

    testWidgets('displays email', (tester) async {
      await pumpProfileScreen(tester);

      expect(find.text('testuser@bu.edu'), findsOneWidget);
    });

    testWidgets('displays bio', (tester) async {
      await pumpProfileScreen(tester);

      expect(find.text('Just a test user'), findsOneWidget);
    });

    testWidgets('displays location', (tester) async {
      await pumpProfileScreen(tester);

      expect(find.text('Warren Towers'), findsOneWidget);
    });

    testWidgets('displays class year', (tester) async {
      await pumpProfileScreen(tester);

      expect(find.text('2025'), findsOneWidget);
    });

    testWidgets('displays interests as chips', (tester) async {
      await pumpProfileScreen(tester);

      expect(find.text('studying'), findsOneWidget);
      expect(find.text('music'), findsOneWidget);
      expect(find.text('sports'), findsOneWidget);
    });

    testWidgets('shows loading indicator when user is null', (tester) async {
      when(mockAuth.currentUser).thenReturn(null);

      await mockNetworkImagesFor(() async {
        await tester.pumpApp(
          const ProfileScreen(),
          authProvider: mockAuth,
          postProvider: mockPostProvider,
        );
        await tester.pump();
      });

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // ── Edit Profile ───────────────────────────────────────────────────

  group('edit profile', () {
    testWidgets('renders Edit Profile button', (tester) async {
      await pumpProfileScreen(tester);

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('Edit Profile button is tappable', (tester) async {
      await pumpProfileScreen(tester);

      // Scroll down to make Edit Profile button visible and verify it exists
      await mockNetworkImagesFor(() async {
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -200),
        );
        await tester.pump();
      });

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });
  });

  // ── Settings Buttons Visible ───────────────────────────────────────

  group('settings buttons visible', () {
    testWidgets('renders Notifications toggle', (tester) async {
      await pumpProfileScreen(tester);

      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('renders Contact & Feedback button', (tester) async {
      await pumpProfileScreen(tester);

      await mockNetworkImagesFor(() async {
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -200),
        );
        await tester.pump();
      });

      expect(find.text('Contact & Feedback'), findsOneWidget);
    });

    testWidgets('renders Legal & Privacy button', (tester) async {
      await pumpProfileScreen(tester);

      await mockNetworkImagesFor(() async {
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -200),
        );
        await tester.pump();
      });

      expect(find.text('Legal & Privacy'), findsOneWidget);
    });

    testWidgets('renders Blocked Users button', (tester) async {
      await pumpProfileScreen(tester);

      await mockNetworkImagesFor(() async {
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.pump();
      });

      expect(find.text('Blocked Users'), findsOneWidget);
    });

    testWidgets('renders Delete Account button', (tester) async {
      await pumpProfileScreen(tester);

      await mockNetworkImagesFor(() async {
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -500),
        );
        await tester.pump();
      });

      expect(find.text('Delete Account'), findsOneWidget);
    });
  });

  // ── Sign Out ───────────────────────────────────────────────────────

  group('sign out', () {
    testWidgets('renders logout icon in AppBar', (tester) async {
      await pumpProfileScreen(tester);

      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('tapping logout shows confirmation dialog', (tester) async {
      await pumpProfileScreen(tester);

      await mockNetworkImagesFor(() async {
        await tester.tap(find.byIcon(Icons.logout));
        await tester.pump();
      });

      expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Sign Out'), findsWidgets);
    });

    testWidgets('confirming sign out calls signOut on providers',
        (tester) async {
      await pumpProfileScreen(tester);

      // Open the dialog
      await mockNetworkImagesFor(() async {
        await tester.tap(find.byIcon(Icons.logout));
        await tester.pump();
      });

      // Tap "Sign Out" in the dialog (last match since AppBar tooltip also exists)
      await mockNetworkImagesFor(() async {
        await tester.tap(find.text('Sign Out').last);
        await tester.pump();
        await tester.pump(); // Allow async signOut to start
      });

      verify(mockPostProvider.cleanup()).called(1);
      verify(mockAuth.signOut()).called(1);
    });
  });
}
