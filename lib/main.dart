import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:facebook_app_events/facebook_app_events.dart';

import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/post_provider.dart';
import 'providers/tab_navigation_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/profile/delete_account_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/feed/create_post_screen.dart';
import 'screens/feed/hangout_invitation_screen.dart';
import 'screens/feed/post_chat_screen.dart';
import 'screens/feed/hangout_screen.dart';
import 'screens/main/main_scaffold.dart';
import 'screens/consent/consent_dialog_screen.dart';
import 'services/deep_link_service.dart';
import 'services/analytics_service.dart';
import 'services/navigation_service.dart';
import 'services/notification_service.dart';
import 'utils/colors.dart';
import 'config/environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read environment from dart-defines
  const envString = String.fromEnvironment('ENV', defaultValue: 'prod');
  final environment = envString == 'dev' ? Environment.dev : Environment.prod;
  EnvironmentConfig.setEnvironment(environment);
  debugPrint('🌍 Running in ${EnvironmentConfig.environmentName} environment');

  try {
    debugPrint('🔥 Initializing Firebase...');
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized successfully');

    // Initialize Facebook App Events for ad attribution (release mode only)
    if (kReleaseMode) {
      final facebookAppEvents = FacebookAppEvents();
      debugPrint('📱 Facebook App Events initialized for ad tracking');
    } else {
      debugPrint('📱 Facebook App Events disabled in debug mode');
    }

    // Initialize Firebase Crashlytics
    debugPrint('💥 Initializing Firebase Crashlytics...');
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    debugPrint('✅ Firebase Crashlytics initialized successfully');

    // Initialize Firebase Analytics (only with consent)
    debugPrint('📊 Checking analytics consent...');
    final hasConsent = await _checkAnalyticsConsent();
    if (hasConsent) {
      AnalyticsService().initialize();
      debugPrint('✅ Firebase Analytics initialized with user consent');
    } else {
      debugPrint('📊 Analytics not initialized - no user consent');
    }

    // Initialize Notification Service for FCM token management
    debugPrint('🔔 Initializing Notification Service...');
    final notificationService = NotificationService();
    notificationService.initializeTokenRefresh();
    notificationService.initializeMessageHandlers();
    debugPrint('✅ Notification Service initialized successfully');
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
    rethrow;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => TabNavigationProvider()),
      ],
      child: const SquadApp(),
    ),
  );
}

/// Check if user has consented to analytics data collection
Future<bool> _checkAnalyticsConsent() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Debug all SharedPreferences data
    final allKeys = prefs.getKeys();
    debugPrint('🚀 APP LAUNCH - All SharedPreferences keys: $allKeys');

    final hasConsent = prefs.getBool('analytics_consent');

    debugPrint('🚀 APP LAUNCH - Analytics consent status: $hasConsent');
    debugPrint(
      '🚀 APP LAUNCH - Consent is null (first time): ${hasConsent == null}',
    );
    debugPrint('🚀 APP LAUNCH - Consent value (if set): $hasConsent');

    // If consent hasn't been set yet, show dialog
    if (hasConsent == null) {
      debugPrint('🚀 APP LAUNCH - No consent found, will show dialog');
      // We'll show the dialog when the app builds, return false for now
      return false;
    }

    debugPrint('🚀 APP LAUNCH - Using stored consent: $hasConsent');
    return hasConsent;
  } catch (e) {
    debugPrint('❌ Error checking analytics consent: $e');
    return false;
  }
}

/// Save analytics consent preference
Future<void> _saveAnalyticsConsent(bool consent) async {
  try {
    debugPrint('💾 CONSENT CHANGE - Saving analytics consent: $consent');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('analytics_consent', consent);

    debugPrint('💾 CONSENT CHANGE - Successfully saved to SharedPreferences');

    // Verify the save worked by reading it back immediately
    final savedValue = prefs.getBool('analytics_consent');
    debugPrint('💾 CONSENT CHANGE - Verification read: $savedValue');

    // List all SharedPreferences keys for debugging
    final allKeys = prefs.getKeys();
    debugPrint('💾 CONSENT CHANGE - All SharedPreferences keys: $allKeys');

    if (consent) {
      // Initialize analytics if user consented
      debugPrint(
        '💾 CONSENT CHANGE - User granted consent, initializing analytics',
      );
      AnalyticsService().initialize();
      debugPrint('✅ Analytics initialized after user consent');
    } else {
      // Disable analytics if user denied consent
      debugPrint(
        '💾 CONSENT CHANGE - User denied consent, disabling analytics',
      );
      AnalyticsService().disable();
      debugPrint('📊 Analytics disabled by user choice');
    }
  } catch (e) {
    debugPrint('❌ Error saving analytics consent: $e');
  }
}

class SquadApp extends StatefulWidget {
  const SquadApp({super.key});

  @override
  State<SquadApp> createState() => _SquadAppState();
}

class _SquadAppState extends State<SquadApp> {
  final DeepLinkService _deepLinkService = DeepLinkService();
  GoRouter? _router;
  bool? _wasAuthenticated;
  bool? _consentStatus; // null = not checked yet, true = given, false = denied
  bool _isCheckingConsent = true;

  @override
  void initState() {
    super.initState();
    debugPrint('🔵 SquadApp initState() started');

    // Check consent status first
    _checkInitialConsent();

    // Initialize deep linking after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🟡 Post-frame callback executing...');
      _deepLinkService.initialize(context);
    });

    debugPrint('🔵 SquadApp initState() completed');
  }

  Future<void> _checkInitialConsent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasConsent = prefs.getBool('analytics_consent');

      setState(() {
        _consentStatus = hasConsent;
        _isCheckingConsent = false;
      });

      // If consent is already determined, create router
      if (hasConsent != null && mounted) {
        _createRouterWithConsent();
      }

      debugPrint('🔍 Initial consent check: $hasConsent');
    } catch (e) {
      debugPrint('❌ Error checking initial consent: $e');
      setState(() {
        _consentStatus = null;
        _isCheckingConsent = false;
      });
    }
  }

  void _createRouterWithConsent() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _router = _createRouter(authProvider);
    });
  }

  Future<void> _handleConsentChoice(bool consent) async {
    debugPrint('🎯 User consent choice: $consent');

    // Save consent
    await _saveAnalyticsConsent(consent);

    // Update state
    setState(() {
      _consentStatus = consent;
    });

    // Create router now that consent is determined
    _createRouterWithConsent();
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      primarySwatch: Colors.blue,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );

    // Show loading screen while checking consent
    if (_isCheckingConsent) {
      return MaterialApp(
        title: 'LinkUp BU',
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Show consent dialog if consent not yet given
    if (_consentStatus == null) {
      return MaterialApp(
        title: 'LinkUp BU',
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: ConsentDialogScreen(onConsentGiven: _handleConsentChoice),
      );
    }

    // Show loading screen while router is being created
    if (_router == null) {
      return MaterialApp(
        title: 'LinkUp BU',
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Show main app with router
    return MaterialApp.router(
      title: 'LinkUp BU',
      theme: theme,
      debugShowCheckedModeBanner: false,
      routerConfig: _router!,
    );
  }

  GoRouter _createRouter(AuthProvider authProvider) {
    return GoRouter(
      navigatorKey: NavigationService.navigatorKey,
      refreshListenable: authProvider,
      initialLocation: '/',
      observers: [
        // Only add analytics observer if user has consented and service is initialized
        if (AnalyticsService().isInitialized &&
            AnalyticsService().observer != null)
          AnalyticsService().observer!,
      ],
      redirect: (context, state) {
        // Add stack trace to understand what's triggering the redirect
        final stackTrace = StackTrace.current;
        final stackLines = stackTrace
            .toString()
            .split('\n')
            .take(10)
            .join('\n');

        debugPrint('🚨 REDIRECT FUNCTION CALLED!');
        debugPrint('🚨 CALL STACK THAT TRIGGERED REDIRECT:\n$stackLines');
        debugPrint('🚨 Current route attempting to navigate to: ${state.uri}');

        final isAuthenticated = authProvider.isAuthenticated;
        final wasAuthenticated = _wasAuthenticated;
        final currentUserInfo = authProvider.currentUser;
        final hasProfile = currentUserInfo?.hasCreatedProfile ?? false;
        final isEmailVerified = currentUserInfo?.isEmailVerified ?? false;
        final isLoading = authProvider.isLoading;

        final currentPath = state.uri.toString();

        // Enhanced Debug Logging with stack trace
        debugPrint('🚦 GoRouter Debug: === NAVIGATION DECISION ===');
        debugPrint('🚦 TRIGGERED BY STACK TRACE:\n$stackLines');
        debugPrint('🚦 Current path: $currentPath');
        debugPrint('🚦 AuthProvider.isAuthenticated: $isAuthenticated');
        debugPrint('🚦 AuthProvider.wasAuthenticated: $wasAuthenticated');
        debugPrint(
          '🚦 AuthProvider.accountDeletionCompleted: ${authProvider.accountDeletionCompleted}',
        );
        debugPrint('🚦 AuthProvider.currentUser: ${currentUserInfo?.toMap()}');
        debugPrint('🚦 hasProfile: $hasProfile');
        debugPrint('🚦 isEmailVerified: $isEmailVerified');
        debugPrint('🚦 AuthProvider.isLoading: $isLoading');

        if (isLoading) {
          debugPrint(
            '🚦 REDIRECT CONDITION: AuthProvider is loading - preventing navigation',
          );
          return null;
        }

        // Check if account deletion was completed - always redirect to login
        if (authProvider.accountDeletionCompleted) {
          debugPrint(
            '🚦 REDIRECT CONDITION: Account deletion completed - redirecting to login',
          );
          return '/login';
        }

        if (!isAuthenticated) {
          debugPrint(
            '🚦 REDIRECT CONDITION: User not authenticated - redirecting to login',
          );
          _wasAuthenticated =
              false; // Explicitly set to false when not authenticated
          return '/login';
        }

        // Check email verification BEFORE profile check
        if (isAuthenticated && !isEmailVerified) {
          if (currentPath != '/email-verification') {
            debugPrint(
              '🚦 REDIRECT CONDITION: Email not verified - redirecting to /email-verification',
            );
            return '/email-verification';
          }
          debugPrint(
            '🚦 Already on email verification screen - no redirect needed',
          );
          return null;
        }

        // Handle authentication state changes and ensure proper routing
        if (wasAuthenticated != isAuthenticated) {
          // Updated tracker to new state
          _wasAuthenticated = isAuthenticated;
          debugPrint(
            '🚦 REDIRECT CONDITION: Auth state changed! wasAuthenticated: $wasAuthenticated -> isAuthenticated: $isAuthenticated',
          );

          if (isAuthenticated && isEmailVerified && hasProfile) {
            debugPrint(
              '🚦 REDIRECT CONDITION: State change - authenticated, verified user with profile - redirecting to /main',
            );
            return '/main';
          }

          if (isAuthenticated && isEmailVerified && !hasProfile) {
            if (currentPath != '/profile-setup') {
              debugPrint(
                '🚦 REDIRECT CONDITION: State change - authenticated, verified user without profile - redirecting to /profile-setup',
              );
              return '/profile-setup';
            }
            debugPrint(
              '🚦 Already on profile setup screen - no redirect needed',
            );
            return null;
          }

          if (isAuthenticated && !isEmailVerified) {
            if (currentPath != '/email-verification') {
              debugPrint(
                '🚦 REDIRECT CONDITION: State change - authenticated but unverified user - redirecting to /email-verification',
              );
              return '/email-verification';
            }
            debugPrint(
              '🚦 Already on email verification screen - no redirect needed',
            );
            return null;
          }
        }

        // Ensure authenticated users with profiles stay on main routes, not login
        if (isAuthenticated &&
            isEmailVerified &&
            hasProfile &&
            currentPath == '/login') {
          debugPrint(
            '🚦 REDIRECT CONDITION: Authenticated, verified user with profile on login page - redirecting to /main',
          );
          return '/main';
        }

        // Ensure authenticated users without profiles go to profile setup, not login
        if (isAuthenticated &&
            isEmailVerified &&
            !hasProfile &&
            currentPath == '/login') {
          debugPrint(
            '🚦 REDIRECT CONDITION: Authenticated, verified user without profile on login page - redirecting to /profile-setup',
          );
          return '/profile-setup';
        }

        // Ensure unverified users go to email verification, not login or other screens
        if (isAuthenticated &&
            !isEmailVerified &&
            currentPath != '/email-verification') {
          debugPrint(
            '🚦 REDIRECT CONDITION: Authenticated but unverified user trying to access $currentPath - redirecting to /email-verification',
          );
          return '/email-verification';
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
          path: '/email-verification',
          builder: (context, state) => const EmailVerificationScreen(),
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
          path: '/profile/delete-account',
          builder: (context, state) => const DeleteAccountScreen(),
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
            return HangoutInvitationScreen(hangoutId: hangoutId);
          },
        ),
        GoRoute(
          path: '/post-chat/:postId',
          builder: (context, state) {
            final postId = state.pathParameters['postId']!;
            debugPrint('🎯 POST CHAT ROUTE - Route hit with postId: $postId');

            // Use listen: false to avoid rebuilds from PostProvider updates
            final postProvider = Provider.of<PostProvider>(
              context,
              listen: false,
            );
            debugPrint('🔍 POST CHAT ROUTE - Getting post by ID: $postId');

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
        ),
        GoRoute(
          path: '/group-members/:postId',
          builder: (context, state) {
            final postId = state.pathParameters['postId']!;
            // Use listen: false to avoid rebuilds from PostProvider updates
            final postProvider = Provider.of<PostProvider>(
              context,
              listen: false,
            );
            final post = postProvider.getPostById(postId);
            if (post == null) {
              return const Scaffold(
                body: Center(child: Text('Post not found')),
              );
            }
            return HangoutScreen(post: post);
          },
        ),
      ],
    );
  }
}
