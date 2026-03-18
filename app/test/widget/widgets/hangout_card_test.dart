import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:provider/provider.dart';
import 'package:squad_app/models/post_model.dart';
import 'package:squad_app/providers/auth_provider.dart';
import 'package:squad_app/providers/post_provider.dart';
import 'package:squad_app/widgets/hangout_card.dart';
import 'package:squad_app/widgets/profile_avatar.dart';

import '../../fixtures/post_fixtures.dart';
import '../../fixtures/user_fixtures.dart';
import '../../helpers/firebase_test_helpers.dart';
import '../../helpers/pump_app.dart';

@GenerateNiceMocks([MockSpec<AuthProvider>(), MockSpec<PostProvider>()])
import 'hangout_card_test.mocks.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  late MockAuthProvider mockAuth;
  late MockPostProvider mockPostProvider;

  setUp(() {
    mockAuth = MockAuthProvider();
    mockPostProvider = MockPostProvider();

    // Default: current user is the post author (basicUser id: 'user-123')
    when(mockAuth.currentUser).thenReturn(UserFixtures.basicUser);
    when(mockPostProvider.isLoading).thenReturn(false);
    when(mockPostProvider.error).thenReturn(null);
  });

  /// Pumps a HangoutCard using pumpApp (no GoRouter — for rendering-only tests)
  Future<void> pumpHangoutCard(
    WidgetTester tester,
    Post post, {
    VoidCallback? onDeleted,
  }) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpApp(
        Scaffold(
          body: SingleChildScrollView(
            child: HangoutCard(post: post, onDeleted: onDeleted),
          ),
        ),
        authProvider: mockAuth,
        postProvider: mockPostProvider,
      );
      await tester.pump();
    });
  }

  /// Pumps a HangoutCard inside GoRouter (for navigation tests)
  Future<void> pumpHangoutCardWithRouter(
    WidgetTester tester,
    Post post, {
    VoidCallback? onDeleted,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: HangoutCard(post: post, onDeleted: onDeleted),
            ),
          ),
        ),
        GoRoute(
          path: '/group-members/:id',
          builder: (context, state) => const Scaffold(
            body: Text('Group Members Page'),
          ),
        ),
      ],
    );

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<PostProvider>.value(value: mockPostProvider),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
    });
  }

  // ── Rendering ──────────────────────────────────────────────────────

  group('rendering', () {
    testWidgets('renders author name', (tester) async {
      await pumpHangoutCard(tester, PostFixtures.upcomingPost);

      expect(find.text(PostFixtures.upcomingPost.authorName), findsOneWidget);
    });

    testWidgets('renders profile avatar', (tester) async {
      await pumpHangoutCard(tester, PostFixtures.upcomingPost);

      expect(find.byType(ProfileAvatar), findsOneWidget);
    });

    testWidgets('renders location with icon', (tester) async {
      await pumpHangoutCard(tester, PostFixtures.upcomingPost);

      expect(find.byIcon(Icons.location_on), findsOneWidget);
      expect(find.text('Marciano Commons'), findsOneWidget);
    });

    testWidgets('renders default location GSU when null', (tester) async {
      // Create a post without location via constructor (copyWith can't set null)
      final post = Post(
        id: 'post-no-loc',
        type: PostType.waving,
        activity: Activity.diningHall,
        description: 'Grab lunch',
        authorId: UserFixtures.basicUser.id,
        authorName: UserFixtures.basicUser.displayName!,
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
        scheduledTime: DateTime(2024, 1, 2, 14, 0, 0),
        status: PostStatus.upcoming,
        participantIds: [UserFixtures.basicUser.id],
      );
      await pumpHangoutCard(tester, post);

      expect(find.text('GSU'), findsOneWidget);
    });

    testWidgets('renders description text', (tester) async {
      await pumpHangoutCard(tester, PostFixtures.upcomingPost);

      expect(
        find.text('Looking for people to grab lunch!'),
        findsOneWidget,
      );
    });
  });

  // ── Participant Count ──────────────────────────────────────────────

  group('participant count', () {
    testWidgets('shows singular "1 member" for single participant',
        (tester) async {
      // upcomingPost has 1 participant
      await pumpHangoutCard(tester, PostFixtures.upcomingPost);

      expect(find.text('1 member'), findsOneWidget);
    });

    testWidgets('shows plural "2 members" for multiple participants',
        (tester) async {
      // ongoingPost has 2 participants
      await pumpHangoutCard(tester, PostFixtures.ongoingPost);

      expect(find.text('2 members'), findsOneWidget);
    });

    testWidgets('shows people icon', (tester) async {
      await pumpHangoutCard(tester, PostFixtures.upcomingPost);

      expect(find.byIcon(Icons.people), findsOneWidget);
    });
  });

  // ── Closed Badge ───────────────────────────────────────────────────

  group('Closed badge', () {
    testWidgets('shows Closed badge when post is locked', (tester) async {
      await pumpHangoutCard(tester, PostFixtures.lockedPost);

      expect(find.text('Closed'), findsOneWidget);
      // The small 8px lock icon in the badge
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('hides Closed badge when post is not locked', (tester) async {
      await pumpHangoutCard(tester, PostFixtures.upcomingPost);

      expect(find.text('Closed'), findsNothing);
    });
  });

  // ── Status Badge ───────────────────────────────────────────────────

  group('status badge', () {
    testWidgets('shows Ongoing badge when dynamicStatus is ongoing',
        (tester) async {
      // Create a post with scheduledTime in the recent past (within 4 hours)
      // so dynamicStatus returns PostStatus.ongoing
      final post = PostFixtures.upcomingPost.copyWith(
        scheduledTime: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await pumpHangoutCard(tester, post);

      expect(find.text('Ongoing'), findsOneWidget);
    });

    testWidgets('shows formatted time when not ongoing', (tester) async {
      // Create a post with scheduledTime in the future so dynamicStatus is upcoming
      final futureTime = DateTime.now().add(const Duration(hours: 3));
      final post = PostFixtures.upcomingPost.copyWith(
        scheduledTime: futureTime,
      );
      await pumpHangoutCard(tester, post);

      // Should not show Ongoing
      expect(find.text('Ongoing'), findsNothing);
      // Should show a time string containing AM or PM
      expect(
        find.textContaining(RegExp(r'(AM|PM)')),
        findsOneWidget,
      );
    });
  });

  // ── Author Menu ────────────────────────────────────────────────────

  group('author menu', () {
    testWidgets('shows menu when user is author', (tester) async {
      await pumpHangoutCard(tester, PostFixtures.upcomingPost);

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('hides menu when user is not author', (tester) async {
      when(mockAuth.currentUser).thenReturn(UserFixtures.secondUser);
      await pumpHangoutCard(tester, PostFixtures.upcomingPost);

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('shows Close option for unlocked post', (tester) async {
      await pumpHangoutCard(tester, PostFixtures.upcomingPost);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('shows Open option for locked post', (tester) async {
      await pumpHangoutCard(tester, PostFixtures.lockedPost);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('shows Delete option', (tester) async {
      await pumpHangoutCard(tester, PostFixtures.upcomingPost);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
    });
  });

  // ── Navigation ─────────────────────────────────────────────────────

  group('navigation', () {
    testWidgets('tapping card navigates to group-members page',
        (tester) async {
      await pumpHangoutCardWithRouter(tester, PostFixtures.upcomingPost);

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.text('Group Members Page'), findsOneWidget);
    });

    testWidgets('does not navigate when user is null', (tester) async {
      when(mockAuth.currentUser).thenReturn(null);
      await pumpHangoutCardWithRouter(tester, PostFixtures.upcomingPost);

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Should stay on same page - Group Members Page should not appear
      expect(find.text('Group Members Page'), findsNothing);
    });
  });
}
