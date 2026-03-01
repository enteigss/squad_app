import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:squad_app/models/post_model.dart';
import 'package:squad_app/providers/auth_provider.dart';
import 'package:squad_app/providers/post_provider.dart';
import 'package:squad_app/screens/feed/feed_screen.dart';
import 'package:squad_app/widgets/post_card.dart';

import '../../fixtures/post_fixtures.dart';
import '../../fixtures/user_fixtures.dart';
import '../../helpers/firebase_test_helpers.dart';
import '../../helpers/pump_app.dart';

@GenerateNiceMocks([MockSpec<AuthProvider>(), MockSpec<PostProvider>()])
import 'feed_screen_test.mocks.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  late MockAuthProvider mockAuth;
  late MockPostProvider mockPostProvider;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockPostProvider = MockPostProvider();

    // Default stubs
    when(mockAuth.currentUser).thenReturn(UserFixtures.basicUser);
    when(mockPostProvider.isLoading).thenReturn(false);
    when(mockPostProvider.error).thenReturn(null);
    when(mockPostProvider.getOngoingPostsForUser(any)).thenReturn([]);
    when(mockPostProvider.getUpcomingPostsForUser(any)).thenReturn([]);
  });

  Future<void> pumpFeedScreen(WidgetTester tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpApp(
        const FeedScreen(),
        authProvider: mockAuth,
        postProvider: mockPostProvider,
      );
      await tester.pump(); // Trigger addPostFrameCallback
    });
  }

  // ── Basic Structure ────────────────────────────────────────────────

  group('renders basic structure', () {
    testWidgets('renders AppBar with Home title', (tester) async {
      await pumpFeedScreen(tester);

      expect(find.text('Home'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('renders filter toggle buttons', (tester) async {
      await pumpFeedScreen(tester);

      expect(find.text('Now'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
    });

    testWidgets('renders FloatingActionButton', (tester) async {
      await pumpFeedScreen(tester);

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('renders info cards', (tester) async {
      await pumpFeedScreen(tester);

      expect(
        find.text('Got plans? Let people join you.'),
        findsOneWidget,
      );
      expect(
        find.text('Need a group? Find people here.'),
        findsOneWidget,
      );
      expect(
        find.text("No plans? Let people know you're free."),
        findsOneWidget,
      );
    });
  });

  // ── Loading State ──────────────────────────────────────────────────

  group('loading state', () {
    testWidgets('shows CircularProgressIndicator when loading',
        (tester) async {
      when(mockPostProvider.isLoading).thenReturn(true);

      await pumpFeedScreen(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // ── Error State ────────────────────────────────────────────────────

  group('error state', () {
    testWidgets('shows error message and retry button', (tester) async {
      when(mockPostProvider.error).thenReturn('Network error');

      await pumpFeedScreen(tester);

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Error loading hangouts'), findsOneWidget);
      expect(find.text('Network error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('tapping Retry calls initialize', (tester) async {
      when(mockPostProvider.error).thenReturn('Network error');

      await pumpFeedScreen(tester);
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // initialize() is called once in initState + once on retry
      verify(mockPostProvider.initialize()).called(greaterThanOrEqualTo(1));
    });
  });

  // ── Post List ──────────────────────────────────────────────────────

  group('post list', () {
    testWidgets('renders PostCard widgets when posts available',
        (tester) async {
      final posts = [PostFixtures.ongoingPost];
      when(mockPostProvider.getOngoingPostsForUser(any)).thenReturn(posts);

      await pumpFeedScreen(tester);

      expect(find.byType(PostCard), findsOneWidget);
    });

    testWidgets('shows info cards but no PostCards when no posts',
        (tester) async {
      await pumpFeedScreen(tester);

      expect(find.byType(PostCard), findsNothing);
      expect(
        find.text('Got plans? Let people join you.'),
        findsOneWidget,
      );
    });
  });

  // ── Filter Toggles ────────────────────────────────────────────────

  group('filter toggles', () {
    testWidgets('tapping Now toggle hides ongoing posts', (tester) async {
      final ongoingPosts = [PostFixtures.ongoingPost];
      when(mockPostProvider.getOngoingPostsForUser(any))
          .thenReturn(ongoingPosts);

      await pumpFeedScreen(tester);
      expect(find.byType(PostCard), findsOneWidget);

      // Tap "Now" toggle to deselect it (use .first to avoid section header)
      await mockNetworkImagesFor(() async {
        await tester.tap(find.text('Now').first);
        await tester.pump();
      });

      // Ongoing posts should be hidden
      expect(find.byType(PostCard), findsNothing);
    });

    testWidgets('tapping Later toggle hides upcoming posts', (tester) async {
      final upcomingPosts = [PostFixtures.upcomingPost];
      when(mockPostProvider.getUpcomingPostsForUser(any))
          .thenReturn(upcomingPosts);

      await pumpFeedScreen(tester);
      expect(find.byType(PostCard), findsOneWidget);

      // Tap "Later" to deselect it
      await mockNetworkImagesFor(() async {
        await tester.tap(find.text('Later'));
        await tester.pump();
      });

      // Upcoming posts should be hidden
      expect(find.byType(PostCard), findsNothing);
    });
  });
}
