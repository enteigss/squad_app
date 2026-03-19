import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:squad_app/models/post_model.dart';
import 'package:squad_app/providers/auth_provider.dart';
import 'package:squad_app/providers/post_provider.dart';
import 'package:squad_app/utils/colors.dart';
import 'package:squad_app/widgets/post_card.dart';

import '../../fixtures/post_fixtures.dart';
import '../../fixtures/user_fixtures.dart';
import '../../helpers/firebase_test_helpers.dart';
import '../../helpers/pump_app.dart';

@GenerateNiceMocks([MockSpec<AuthProvider>(), MockSpec<PostProvider>()])
import 'post_card_test.mocks.dart';

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

  /// Pumps a PostCard using pumpApp (no GoRouter — for rendering-only tests)
  Future<void> pumpPostCard(
    WidgetTester tester,
    Post post, {
    bool showTimeLabel = true,
    VoidCallback? onDeleted,
  }) async {
    await tester.pumpApp(
      Scaffold(
        body: SingleChildScrollView(
          child: PostCard(
            post: post,
            showTimeLabel: showTimeLabel,
            onDeleted: onDeleted,
          ),
        ),
      ),
      authProvider: mockAuth,
      postProvider: mockPostProvider,
    );
  }

  /// Pumps a PostCard inside GoRouter (for navigation tests)
  Future<void> pumpPostCardWithRouter(
    WidgetTester tester,
    Post post, {
    bool showTimeLabel = true,
    VoidCallback? onDeleted,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: PostCard(
                post: post,
                showTimeLabel: showTimeLabel,
                onDeleted: onDeleted,
              ),
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

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ChangeNotifierProvider<PostProvider>.value(value: mockPostProvider),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  // ── Rendering ──────────────────────────────────────────────────────

  group('rendering', () {
    testWidgets('renders author name for walking post', (tester) async {
      await pumpPostCard(tester, PostFixtures.ongoingPost);

      expect(find.textContaining('Test User'), findsOneWidget);
    });

    testWidgets('renders description when present', (tester) async {
      await pumpPostCard(tester, PostFixtures.ongoingPost);

      expect(
        find.text('Walking to class, anyone want to join?'),
        findsOneWidget,
      );
    });

    testWidgets('hides description when null', (tester) async {
      // Create a post without description via constructor directly
      final post = Post(
        id: 'post-no-desc',
        type: PostType.walking,
        activity: Activity.walking,
        authorId: UserFixtures.basicUser.id,
        authorName: UserFixtures.basicUser.displayName!,
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
        status: PostStatus.ongoing,
        participantIds: [UserFixtures.basicUser.id],
        location: 'CAS',
      );
      await pumpPostCard(tester, post);

      // Only the activity text should be present, no description
      expect(find.textContaining('Walking from CAS'), findsOneWidget);
      // Verify the specific description from ongoingPost is not shown
      expect(
        find.text('Walking to class, anyone want to join?'),
        findsNothing,
      );
    });

    testWidgets('displays participant count', (tester) async {
      // ongoingPost has 2 participants
      await pumpPostCard(tester, PostFixtures.ongoingPost);

      expect(find.byIcon(Icons.people), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('displays tap to view hint', (tester) async {
      await pumpPostCard(tester, PostFixtures.ongoingPost);

      expect(find.text('Tap to view ›'), findsOneWidget);
    });

    testWidgets('hides header for waving type', (tester) async {
      // upcomingPost is waving type
      await pumpPostCard(tester, PostFixtures.upcomingPost);

      // Should not show walking or raising emojis in header
      expect(find.textContaining('is...'), findsNothing);
      expect(find.textContaining('wants to...'), findsNothing);
    });

    testWidgets('shows header for walking type', (tester) async {
      await pumpPostCard(tester, PostFixtures.ongoingPost);

      expect(find.text('🚶'), findsAny);
      expect(find.textContaining('is...'), findsOneWidget);
    });

    testWidgets('shows header for raising type', (tester) async {
      final post = PostFixtures.ongoingPost.copyWith(
        type: PostType.raising,
        activity: Activity.studying,
        location: 'Mugar Library',
      );
      await pumpPostCard(tester, post);

      expect(find.text('🙋'), findsAny);
      expect(find.textContaining('wants to...'), findsOneWidget);
    });
  });

  // ── Accent Color Strip ─────────────────────────────────────────────

  group('accent color strip', () {
    testWidgets('shows green accent for walking post', (tester) async {
      await pumpPostCard(tester, PostFixtures.ongoingPost);

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasGreenAccent = containers.any((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration && c.constraints?.maxWidth == 4) {
          return decoration.color == AppColors.doingGreen;
        }
        return false;
      });
      expect(hasGreenAccent, isTrue);
    });

    testWidgets('shows blue accent for raising post', (tester) async {
      final post = PostFixtures.ongoingPost.copyWith(
        type: PostType.raising,
        activity: Activity.studying,
      );
      await pumpPostCard(tester, post);

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBlueAccent = containers.any((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration && c.constraints?.maxWidth == 4) {
          return decoration.color == Colors.blue;
        }
        return false;
      });
      expect(hasBlueAccent, isTrue);
    });

    testWidgets('shows purple accent for waving post', (tester) async {
      await pumpPostCard(tester, PostFixtures.upcomingPost);

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasPurpleAccent = containers.any((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration && c.constraints?.maxWidth == 4) {
          return decoration.color == Colors.purple;
        }
        return false;
      });
      expect(hasPurpleAccent, isTrue);
    });
  });

  // ── Activity Body Text ─────────────────────────────────────────────

  group('activity body text', () {
    testWidgets('walking shows from/to locations', (tester) async {
      // ongoingPost: walking, location: CAS, locationTo: GSU
      await pumpPostCard(tester, PostFixtures.ongoingPost);

      expect(find.textContaining('Walking from CAS to GSU'), findsOneWidget);
    });

    testWidgets('walking shows from only when no locationTo', (tester) async {
      final post = PostFixtures.ongoingPost.copyWith(locationTo: null);
      await pumpPostCard(tester, post);

      expect(find.textContaining('Walking from CAS'), findsOneWidget);
    });

    testWidgets('raising shows activity at location', (tester) async {
      final post = PostFixtures.ongoingPost.copyWith(
        type: PostType.raising,
        activity: Activity.studying,
        location: 'Mugar Library',
        locationTo: null,
      );
      await pumpPostCard(tester, post);

      expect(find.textContaining('Studying at Mugar Library'), findsOneWidget);
    });

    testWidgets('waving shows wave emoji and is free', (tester) async {
      await pumpPostCard(tester, PostFixtures.upcomingPost);

      expect(find.textContaining('👋'), findsOneWidget);
      expect(find.textContaining('is free'), findsOneWidget);
    });

    testWidgets('custom activity shows custom text', (tester) async {
      final post = PostFixtures.customActivityPost.copyWith(
        type: PostType.raising,
      );
      await pumpPostCard(tester, post);

      expect(
        find.textContaining('Board game night'),
        findsOneWidget,
      );
    });

    testWidgets('raising shows correct activity emoji', (tester) async {
      final post = PostFixtures.ongoingPost.copyWith(
        type: PostType.raising,
        activity: Activity.studying,
        location: 'Mugar',
        locationTo: null,
      );
      await pumpPostCard(tester, post);

      expect(find.text('📚'), findsAny);
    });
  });

  // ── Time Label ─────────────────────────────────────────────────────

  group('time label', () {
    testWidgets('shows time when showTimeLabel is true', (tester) async {
      await pumpPostCard(tester, PostFixtures.ongoingPost, showTimeLabel: true);

      // The fixed date is Jan 1 2024 12:00 -> "12:00 PM"
      expect(find.textContaining('12:00 PM'), findsOneWidget);
    });

    testWidgets('hides time when showTimeLabel is false', (tester) async {
      await pumpPostCard(
        tester,
        PostFixtures.ongoingPost,
        showTimeLabel: false,
      );

      expect(find.textContaining('12:00 PM'), findsNothing);
    });
  });

  // ── Author Menu ────────────────────────────────────────────────────

  group('author menu', () {
    testWidgets('shows menu when user is author', (tester) async {
      // basicUser.id == ongoingPost.authorId
      await pumpPostCard(tester, PostFixtures.ongoingPost);

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('hides menu when user is not author', (tester) async {
      when(mockAuth.currentUser).thenReturn(UserFixtures.secondUser);
      await pumpPostCard(tester, PostFixtures.ongoingPost);

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('menu shows Lock Post for unlocked post', (tester) async {
      await pumpPostCard(tester, PostFixtures.ongoingPost);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Lock Post'), findsOneWidget);
    });

    testWidgets('menu shows Unlock Post for locked post', (tester) async {
      await pumpPostCard(tester, PostFixtures.lockedPost);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Unlock Post'), findsOneWidget);
    });

    testWidgets('menu shows Delete Post option', (tester) async {
      await pumpPostCard(tester, PostFixtures.ongoingPost);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Delete Post'), findsOneWidget);
    });

    testWidgets('tapping Delete shows confirmation dialog', (tester) async {
      await pumpPostCard(tester, PostFixtures.ongoingPost);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Post'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('confirming delete calls postProvider.deletePost',
        (tester) async {
      when(mockPostProvider.deletePost(any)).thenAnswer((_) async => true);
      await pumpPostCard(tester, PostFixtures.ongoingPost);

      // Open menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap Delete Post
      await tester.tap(find.text('Delete Post'));
      await tester.pumpAndSettle();

      // Confirm delete in dialog
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(mockPostProvider.deletePost(PostFixtures.ongoingPost.id))
          .called(1);
    });

    testWidgets('tapping Lock calls postProvider.lockPost', (tester) async {
      when(mockPostProvider.lockPost(any)).thenAnswer((_) async => true);
      await pumpPostCard(tester, PostFixtures.ongoingPost);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lock Post'));
      await tester.pumpAndSettle();

      verify(mockPostProvider.lockPost(PostFixtures.ongoingPost.id)).called(1);
    });
  });

  // ── Navigation ─────────────────────────────────────────────────────

  group('navigation', () {
    testWidgets('tapping card navigates to group-members page',
        (tester) async {
      await pumpPostCardWithRouter(tester, PostFixtures.ongoingPost);

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.text('Group Members Page'), findsOneWidget);
    });
  });

  // ── Author Name Formatting ─────────────────────────────────────────

  group('author name formatting', () {
    testWidgets('formats with dorm and year', (tester) async {
      final post = PostFixtures.ongoingPost.copyWith(
        authorDorm: 'Warren',
        authorYear: 'sophomore',
      );
      await pumpPostCard(tester, post);

      expect(find.textContaining("(Warren, '28)"), findsOneWidget);
    });

    testWidgets('formats with dorm only', (tester) async {
      final post = PostFixtures.ongoingPost.copyWith(
        authorDorm: 'Warren',
        authorYear: null,
      );
      await pumpPostCard(tester, post);

      expect(find.textContaining('(Warren)'), findsOneWidget);
    });

    testWidgets('shows plain name when both dorm and year are null',
        (tester) async {
      final post = PostFixtures.ongoingPost.copyWith(
        authorDorm: null,
        authorYear: null,
      );
      await pumpPostCard(tester, post);

      // Should find plain name in the header "is..." text
      expect(find.textContaining('Test User is...'), findsOneWidget);
      // Should NOT have parentheses
      expect(find.textContaining('('), findsNothing);
    });
  });
}
