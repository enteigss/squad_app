import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_app/providers/auth_provider.dart';
import 'package:squad_app/providers/post_provider.dart';
import 'package:squad_app/providers/tab_navigation_provider.dart';
import 'package:squad_app/screens/feed/create_post_screen.dart';
import 'package:squad_app/widgets/custom_button.dart';

import '../../fixtures/user_fixtures.dart';
import '../../helpers/firebase_test_helpers.dart';
import '../../helpers/pump_app.dart';

@GenerateNiceMocks([
  MockSpec<AuthProvider>(),
  MockSpec<PostProvider>(),
  MockSpec<TabNavigationProvider>(),
])
import 'create_post_screen_test.mocks.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  late MockAuthProvider mockAuth;
  late MockPostProvider mockPostProvider;
  late MockTabNavigationProvider mockTabProvider;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockPostProvider = MockPostProvider();
    mockTabProvider = MockTabNavigationProvider();

    // Use gender 'man' to match CreatePostScreen validation logic
    when(mockAuth.currentUser)
        .thenReturn(UserFixtures.custom(gender: 'man'));
    when(mockPostProvider.isLoading).thenReturn(false);
    when(mockPostProvider.error).thenReturn(null);
  });

  Future<void> pumpCreatePostScreen(WidgetTester tester) async {
    await tester.pumpApp(
      const CreatePostScreen(),
      authProvider: mockAuth,
      postProvider: mockPostProvider,
      tabNavigationProvider: mockTabProvider,
    );
    await tester.pump();
  }

  // ── Form Fields Present ────────────────────────────────────────────

  group('form fields present', () {
    testWidgets('renders AppBar with Create Hangout title', (tester) async {
      await pumpCreatePostScreen(tester);

      expect(find.byType(AppBar), findsOneWidget);
      // "Create Hangout" appears in AppBar title and in the submit button
      expect(find.text('Create Hangout'), findsWidgets);
    });

    testWidgets('renders title input field', (tester) async {
      await pumpCreatePostScreen(tester);

      expect(find.text('What are you planning?'), findsOneWidget);
      expect(
        find.text('Basketball at the park, coffee meetup, study session...'),
        findsOneWidget,
      );
    });

    testWidgets('renders description field', (tester) async {
      await pumpCreatePostScreen(tester);

      expect(find.text('Tell us more (optional)'), findsOneWidget);
    });

    testWidgets('renders location selector', (tester) async {
      await pumpCreatePostScreen(tester);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pump();

      expect(find.text('Where will it be?'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
    });

    testWidgets('renders date/time selector', (tester) async {
      await pumpCreatePostScreen(tester);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pump();

      expect(find.text('When will it be?'), findsOneWidget);
      expect(find.text('Now (ongoing)'), findsOneWidget);
      expect(find.text('Schedule for later'), findsOneWidget);
    });

    testWidgets('renders gender preference selector', (tester) async {
      await pumpCreatePostScreen(tester);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pump();

      expect(
        find.text('Who are you looking to hang out with?'),
        findsOneWidget,
      );
      expect(find.text('Men'), findsOneWidget);
      expect(find.text('Women'), findsOneWidget);
      expect(find.text('Non-binary'), findsOneWidget);
    });

    testWidgets('renders max participants selector', (tester) async {
      await pumpCreatePostScreen(tester);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -600),
      );
      await tester.pump();

      expect(find.text('How many people can join?'), findsOneWidget);
      expect(find.text('Set participant limit?'), findsOneWidget);
    });

    testWidgets('renders Create Hangout button', (tester) async {
      await pumpCreatePostScreen(tester);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -800),
      );
      await tester.pump();

      expect(find.text('Create Hangout'), findsWidgets);
    });
  });

  // ── Suggestions ────────────────────────────────────────────────────

  group('suggestions', () {
    testWidgets('tapping suggestions header expands suggestions',
        (tester) async {
      await pumpCreatePostScreen(tester);

      await tester.tap(find.text('Need inspiration? Tap for suggestions'));
      await tester.pump();

      expect(find.text('Popular activity ideas:'), findsOneWidget);
    });

    testWidgets('expanding suggestions shows suggestion categories',
        (tester) async {
      await pumpCreatePostScreen(tester);

      // Expand suggestions
      await tester.tap(find.text('Need inspiration? Tap for suggestions'));
      await tester.pump();

      // Verify suggestion categories are rendered
      expect(find.text('Boston Hotspots'), findsOneWidget);
      expect(find.text('BU Hotspots'), findsOneWidget);
    });
  });

  // ── Date/Time Picker ───────────────────────────────────────────────

  group('date/time picker', () {
    testWidgets('tapping Now selects now option', (tester) async {
      await pumpCreatePostScreen(tester);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pump();

      await tester.tap(find.text('Now (ongoing)'));
      await tester.pump();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  // ── Validation Errors ──────────────────────────────────────────────

  group('validation errors', () {
    testWidgets('submitting empty form shows title validation error',
        (tester) async {
      await pumpCreatePostScreen(tester);

      // Scroll to the Create Hangout button
      await tester.scrollUntilVisible(
        find.byType(CustomButton),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.byType(CustomButton));
      await tester.pump();

      // Scroll back to top to see the validation error on the title field
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 500),
      );
      await tester.pump();

      expect(
        find.text('Please enter a title for your hangout'),
        findsOneWidget,
      );
    });

    testWidgets('submitting with title but no date shows snackbar error',
        (tester) async {
      await pumpCreatePostScreen(tester);

      // Enter a title
      await tester.enterText(
        find.byType(TextFormField).first,
        'Test Hangout',
      );
      await tester.pump();

      // Scroll to the Create Hangout button
      await tester.scrollUntilVisible(
        find.byType(CustomButton),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.byType(CustomButton));
      await tester.pump();

      expect(find.text('Please select a date and time'), findsOneWidget);
    });
  });

  // ── Gender Selector ────────────────────────────────────────────────

  group('gender selector', () {
    testWidgets('all genders selected by default', (tester) async {
      await pumpCreatePostScreen(tester);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pump();

      expect(
        find.text('All genders selected - everyone can join!'),
        findsOneWidget,
      );
    });
  });

  // ── Navigation ─────────────────────────────────────────────────────

  group('navigation', () {
    testWidgets('back arrow calls navigateToHangouts', (tester) async {
      await pumpCreatePostScreen(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      verify(mockTabProvider.navigateToHangouts()).called(1);
    });
  });

  // ── Max Participants ───────────────────────────────────────────────

  group('max participants', () {
    testWidgets('toggling limit shows increment/decrement controls',
        (tester) async {
      await pumpCreatePostScreen(tester);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -600),
      );
      await tester.pump();

      // Toggle the switch
      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(find.text('10 people'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });
  });
}
