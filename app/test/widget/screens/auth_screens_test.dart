import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_app/providers/auth_provider.dart';
import 'package:squad_app/screens/auth/login_screen.dart';
import 'package:squad_app/screens/auth/profile_setup_screen.dart';
import 'package:squad_app/screens/auth/email_verification_screen.dart';
import 'package:squad_app/services/email_verification_service.dart';
import 'package:squad_app/widgets/google_sign_in_button.dart';
import 'package:squad_app/widgets/apple_sign_in_button.dart';
import '../../helpers/pump_app.dart';

@GenerateNiceMocks([
  MockSpec<AuthProvider>(),
  MockSpec<EmailVerificationService>(),
])
import 'auth_screens_test.mocks.dart';

void main() {
  late MockAuthProvider mockAuth;

  setUp(() {
    mockAuth = MockAuthProvider();
  });

  // ── LoginScreen ─────────────────────────────────────────────────────

  group('LoginScreen', () {
    testWidgets('renders Google sign-in button', (tester) async {
      await tester.pumpApp(const LoginScreen(), authProvider: mockAuth);

      expect(find.byType(GoogleSignInButton), findsOneWidget);
      expect(find.text('Sign in with BU Google Account'), findsOneWidget);
    });

    testWidgets('renders Apple sign-in button', (tester) async {
      await tester.pumpApp(const LoginScreen(), authProvider: mockAuth);

      expect(find.byType(AppleSignInButton), findsOneWidget);
      expect(find.text('Sign in with Apple'), findsOneWidget);
    });

    testWidgets('renders app title and subtitle', (tester) async {
      await tester.pumpApp(const LoginScreen(), authProvider: mockAuth);

      expect(find.text('LinkUp BU'), findsOneWidget);
      expect(find.text('Boston University Students Only'), findsOneWidget);
    });

    testWidgets('email/password fields hidden by default', (tester) async {
      await tester.pumpApp(const LoginScreen(), authProvider: mockAuth);

      // No TextFormFields should be visible (email/password are hidden)
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('email/password fields appear after 5 logo taps', (
      tester,
    ) async {
      await tester.pumpApp(const LoginScreen(), authProvider: mockAuth);

      // Tap the logo image 5 times to reveal debug email fields
      final logo = find.byType(Image);
      for (var i = 0; i < 5; i++) {
        await tester.tap(logo);
        await tester.pump();
      }

      // Email and password fields should now be visible
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('shows validation errors on empty email submit', (
      tester,
    ) async {
      await tester.pumpApp(const LoginScreen(), authProvider: mockAuth);

      // Reveal email/password fields
      final logo = find.byType(Image);
      for (var i = 0; i < 5; i++) {
        await tester.tap(logo);
        await tester.pump();
      }

      // Scroll down to the Sign In button (it's below the fold)
      await tester.scrollUntilVisible(
        find.text('Sign In'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // Tap Sign In without entering anything
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter email'), findsOneWidget);
    });
  });

  // ── ProfileSetupScreen ────────────────────────────────────────────

  group('ProfileSetupScreen', () {
    testWidgets('renders Full Name field', (tester) async {
      await tester.pumpApp(const ProfileSetupScreen(), authProvider: mockAuth);

      expect(find.text('Enter your full name'), findsOneWidget);
    });

    testWidgets('renders Class Year dropdown', (tester) async {
      await tester.pumpApp(const ProfileSetupScreen(), authProvider: mockAuth);

      expect(find.text('Select your class year'), findsOneWidget);
    });

    testWidgets('renders gender selection options', (tester) async {
      await tester.pumpApp(const ProfileSetupScreen(), authProvider: mockAuth);

      // Scroll down to find gender options
      await tester.scrollUntilVisible(
        find.text('Woman'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Woman'), findsOneWidget);
      expect(find.text('Man'), findsOneWidget);
      expect(find.text('Non-binary'), findsOneWidget);
      expect(find.text('Prefer not to say'), findsOneWidget);
    });

    testWidgets('renders popular interest chips', (tester) async {
      await tester.pumpApp(const ProfileSetupScreen(), authProvider: mockAuth);

      // Scroll down to interests section
      await tester.scrollUntilVisible(
        find.text('Sports'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Sports'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
    });

    testWidgets('renders Complete Profile button', (tester) async {
      await tester.pumpApp(const ProfileSetupScreen(), authProvider: mockAuth);

      // Scroll to the bottom
      await tester.scrollUntilVisible(
        find.text('Complete Profile'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Complete Profile'), findsOneWidget);
    });
  });

  // ── EmailVerificationScreen ───────────────────────────────────────

  group('EmailVerificationScreen', () {
    late MockEmailVerificationService mockVerificationService;

    setUp(() {
      mockVerificationService = MockEmailVerificationService();
      // canResendCode is called during initState
      when(
        mockVerificationService.canResendCode(),
      ).thenAnswer((_) async => true);
      when(
        mockVerificationService.getResendCooldownSeconds(),
      ).thenAnswer((_) async => 0);
    });

    // Helper to set a taller viewport (screen overflows at default 600 height)
    void setTallViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
    }

    testWidgets('renders email input with BU hint', (tester) async {
      setTallViewport(tester);
      await tester.pumpApp(
        EmailVerificationScreen(verificationService: mockVerificationService),
        authProvider: mockAuth,
      );

      expect(find.text('yourname@bu.edu'), findsOneWidget);
    });

    testWidgets('renders Send Verification Code button', (tester) async {
      setTallViewport(tester);
      await tester.pumpApp(
        EmailVerificationScreen(verificationService: mockVerificationService),
        authProvider: mockAuth,
      );

      expect(find.text('Send Verification Code'), findsOneWidget);
    });

    testWidgets('renders sign out button in AppBar', (tester) async {
      setTallViewport(tester);
      await tester.pumpApp(
        EmailVerificationScreen(verificationService: mockVerificationService),
        authProvider: mockAuth,
      );

      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });
  });
}
