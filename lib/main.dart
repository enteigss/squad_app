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
import 'providers/tab_navigation_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => TabNavigationProvider()),
      ],
      child: const SquadApp(),
    ),
  );
}

class SquadApp extends StatefulWidget {
  const SquadApp({super.key});

  @override
  State<SquadApp> createState() => _SquadAppState();
}

class _SquadAppState extends State<SquadApp> {
  final DeepLinkService _deepLinkService = DeepLinkService();
  late final GoRouter _router;
  bool? _wasAuthenticated;

  @override
  void initState() {
    super.initState();
    
    // Initialize auth tracking variable and router
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _router = _createRouter(authProvider);
    
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
      routerConfig: _router,
    );
  }

  GoRouter _createRouter(AuthProvider authProvider) {

    return GoRouter(
      navigatorKey: NavigationService.navigatorKey,
      refreshListenable: authProvider,
      initialLocation: '/',
      observers: [AnalyticsService().observer],
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final wasAuthenticated = _wasAuthenticated;
        final currentUserInfo = authProvider.currentUser;
        final hasProfile = currentUserInfo?.hasCreatedProfile ?? false;
        final isLoading = authProvider.isLoading;

        final currentPath = state.uri.toString();

        // Enhanced Debug Logging
        debugPrint('🚦 GoRouter Debug: === NAVIGATION DECISION ===');
        debugPrint('🚦 Current path: $currentPath');
        debugPrint('🚦 AuthProvider.isAuthenticated: $isAuthenticated');
        debugPrint('🚦 AuthProvider.wasAuthenticated: $wasAuthenticated');
        debugPrint('🚦 AuthProvider.currentUser: ${currentUserInfo?.toMap()}');
        debugPrint('🚦 hasProfile: $hasProfile');

        if (isLoading) {
          debugPrint(
            ' GoRouter: AuthProvider is loading - preventing navigation',
          );
          return null;
        }

        if (!isAuthenticated) {
            _wasAuthenticated = isAuthenticated;
            return '/login';
        }

        // Only run redirect rules if auth state has changed
        if (wasAuthenticated != isAuthenticated) {
          // Updated tracker to new state 
          _wasAuthenticated = isAuthenticated;
          debugPrint('🚦 Auth state changed! Running redirect logic...');

          if (isAuthenticated && hasProfile) {
            return '/main';
          }

          if (isAuthenticated && !hasProfile) {
            if (currentPath != '/profile-setup') {
              return '/profile-setup';
            }
            return null;
          }

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
          path: '/profile',
          builder: (context, state) => const MainScaffold(initialIndex: 2),
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
