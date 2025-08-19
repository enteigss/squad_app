import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/post_provider.dart';
import 'providers/user_preferences_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/auth/preferences_screen.dart';
import 'screens/auth/availability_screen.dart';
import 'screens/home/group_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/feed/create_post_screen.dart';
import 'screens/feed/hangout_detail_screen.dart';
import 'screens/main/main_scaffold.dart';
import 'services/deep_link_service.dart';
import 'utils/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return MaterialApp.router(
            title: 'Squad App',
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
      initialLocation: '/',
      redirect: (context, state) {
        final isLoggedIn = authProvider.isAuthenticated;
        final hasProfile = authProvider.currentUser?.hasCreatedProfile ?? false;
        final hasCompletedPreferences =
            authProvider.currentUser?.hasCompletedPreferences ?? false;
        final profileCompleted =
            authProvider.currentUser?.profileCompleted ?? false;

        final currentPath = state.uri.toString();

        // Debug: Prevent infinite loops by not redirecting if already on target path
        print(
          'GoRouter Debug: isLoggedIn=$isLoggedIn, hasProfile=$hasProfile, hasCompletedPreferences=$hasCompletedPreferences, profileCompleted=$profileCompleted, currentPath=$currentPath',
        );

        // If not logged in, redirect to login
        if (!isLoggedIn) {
          if (currentPath != '/login') {
            return '/login';
          }
          return null;
        }

        // If logged in and all complete, redirect to main from auth screens
        if (isLoggedIn && profileCompleted) {
          if (currentPath == '/login' ||
              currentPath == '/profile-setup' ||
              currentPath == '/preferences' ||
              currentPath == '/availability' ||
              currentPath == '/') {
            return '/main';
          }
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
      ],
    );
  }
}
