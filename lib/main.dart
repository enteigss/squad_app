import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/post_provider.dart';
import 'providers/user_preferences_provider.dart';
import 'providers/feedback_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/auth/preferences_screen.dart';
import 'screens/auth/availability_screen.dart';
import 'screens/home/group_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/feed/create_post_screen.dart';
import 'screens/feed/hangout_detail_screen.dart';
import 'screens/feed/post_chat_screen.dart';
import 'screens/feed/group_members_screen.dart';
import 'screens/main/main_scaffold.dart';
import 'services/deep_link_service.dart';
import 'services/analytics_service.dart';
import 'services/navigation_service.dart';
import 'services/notification_service.dart';
import 'utils/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint('🔥 Initializing Firebase...');
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized successfully');

    // Initialize Firebase Crashlytics
    debugPrint('💥 Initializing Firebase Crashlytics...');
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    debugPrint('✅ Firebase Crashlytics initialized successfully');

    // Initialize Firebase Analytics
    debugPrint('📊 Initializing Firebase Analytics...');
    AnalyticsService().initialize();
    debugPrint('✅ Firebase Analytics initialized successfully');

    // Initialize Notification Service for FCM token management
    debugPrint('🔔 Initializing Notification Service...');
    final notificationService = NotificationService();
    notificationService.initializeTokenRefresh();
    debugPrint('✅ Notification Service initialized successfully');
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
    rethrow;
  }

  runApp(const SquadApp());
}

class SquadApp extends StatefulWidget {
  const SquadApp({super.key});

  @override
  State<SquadApp> createState() => _SquadAppState();
}

class _SquadAppState extends State<SquadApp> {
  final DeepLinkService _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    // Initialize deep linking after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deepLinkService.initialize(context);
    });
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => UserPreferencesProvider()),
        ChangeNotifierProvider(create: (_) => FeedbackProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return MaterialApp.router(
            title: 'LinkUp BU',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              primaryColor: AppColors.primary,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            routerConfig: _createRouter(authProvider),
          );
        },
      ),
    );
  }

  GoRouter _createRouter(AuthProvider authProvider) {
    return GoRouter(
      navigatorKey: NavigationService.navigatorKey,
      initialLocation: '/',
      observers: [AnalyticsService().observer],
      redirect: (context, state) {
        final isLoggedIn = authProvider.isAuthenticated;
        final currentUserInfo = authProvider.currentUser;
        final hasProfile = currentUserInfo?.hasCreatedProfile ?? false;
        final hasCompletedPreferences =
            currentUserInfo?.hasCompletedPreferences ?? false;
        final profileCompleted = currentUserInfo?.profileCompleted ?? false;
        final isLoading = authProvider.isLoading;

        final currentPath = state.uri.toString();

        // Enhanced Debug Logging
        debugPrint('🚦 GoRouter Debug: === NAVIGATION DECISION ===');
        debugPrint('🚦 Current path: $currentPath');
        debugPrint('🚦 AuthProvider.isAuthenticated: $isLoggedIn');
        debugPrint('🚦 AuthProvider.currentUser: ${currentUserInfo?.toMap()}');
        debugPrint('🚦 hasProfile: $hasProfile');
        debugPrint('🚦 hasCompletedPreferences: $hasCompletedPreferences');
        debugPrint('🚦 profileCompleted: $profileCompleted');

        if (isLoading) {
          debugPrint(
            ' GoRouter: AuthProvider is loading - preventing navigation',
          );
          return null;
        }

        // If not logged in, redirect to login
        if (!isLoggedIn) {
          if (currentPath != '/login') {
            return '/login';
          }
          return null;
        }

        // If logged in and all complete, redirect to main from auth screens only
        if (isLoggedIn && profileCompleted) {
          if (currentPath == '/login' ||
              currentPath == '/profile-setup' ||
              currentPath == '/preferences' ||
              currentPath == '/availability' ||
              currentPath == '/') {
            return '/main';
          }
          // Don't redirect if already on main app screens like /squads, /feed, /profile, etc.
          return null;
        }

        // If logged in but incomplete profile, determine next step
        if (isLoggedIn && !profileCompleted) {
          // No basic profile yet
          if (!hasProfile) {
            if (currentPath != '/profile-setup') {
              return '/profile-setup';
            }
            return null;
          }

          // Has basic profile but no preferences
          if (!hasCompletedPreferences) {
            if (currentPath != '/preferences') {
              return '/preferences';
            }
            return null;
          }

          // Has preferences but not availability
          if (currentPath != '/availability') {
            return '/availability';
          }
          return null;
        }

        debugPrint('✅ No redirect needed');
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/profile-setup',
          builder: (context, state) => const ProfileSetupScreen(),
        ),
        GoRoute(
          path: '/preferences',
          builder: (context, state) => const PreferencesScreen(),
        ),
        GoRoute(
          path: '/availability',
          builder: (context, state) => const AvailabilityScreen(),
        ),
        GoRoute(
          path: '/main',
          builder: (context, state) => const MainScaffold(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const MainScaffold(initialIndex: 0),
        ),
        GoRoute(
          path: '/feed',
          builder: (context, state) => const MainScaffold(initialIndex: 1),
        ),
        GoRoute(
          path: '/squads',
          builder: (context, state) => const MainScaffold(initialIndex: 2),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const MainScaffold(initialIndex: 3),
        ),
        GoRoute(
          path: '/group',
          builder: (context, state) => const GroupScreen(),
        ),
        GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
        GoRoute(
          path: '/create-post',
          builder: (context, state) => const CreatePostScreen(),
        ),
        GoRoute(
          path: '/hangout/:hangoutId',
          builder: (context, state) {
            final hangoutId = state.pathParameters['hangoutId']!;
            return HangoutDetailScreen(hangoutId: hangoutId);
          },
        ),
        GoRoute(
          path: '/post-chat/:postId',
          builder: (context, state) {
            final postId = state.pathParameters['postId']!;
            debugPrint('🎯 POST CHAT ROUTE - Route hit with postId: $postId');

            return Consumer<PostProvider>(
              builder: (context, postProvider, child) {
                debugPrint('🔍 POST CHAT ROUTE - Consumer builder called');
                debugPrint('🔍 Getting post by ID: $postId');

                final post = postProvider.getPostById(postId);
                debugPrint('📋 Post found: ${post != null}');

                if (post != null) {
                  debugPrint(
                    '✅ Post details - ID: ${post.id}, Title: ${post.title}',
                  );
                }

                if (post == null) {
                  debugPrint('❌ Post not found! Showing error screen');
                  return const Scaffold(
                    body: Center(child: Text('Post not found')),
                  );
                }

                debugPrint('🎉 Returning PostChatScreen with post');
                return PostChatScreen(post: post);
              },
            );
          },
        ),
        GoRoute(
          path: '/group-members/:postId',
          builder: (context, state) {
            final postId = state.pathParameters['postId']!;
            return Consumer<PostProvider>(
              builder: (context, postProvider, child) {
                final post = postProvider.getPostById(postId);
                if (post == null) {
                  return const Scaffold(
                    body: Center(child: Text('Post not found')),
                  );
                }
                return GroupMembersScreen(post: post);
              },
            );
          },
        ),
      ],
    );
  }
}
