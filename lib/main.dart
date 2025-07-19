import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/group_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'utils/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SquadApp());
}

class SquadApp extends StatelessWidget {
  const SquadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
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

        // If not logged in, redirect to login
        if (!isLoggedIn &&
            state.uri.toString() != '/login' &&
            state.uri.toString() != '/register') {
          return '/login';
        }

        // If logged in but no profile, redirect to profile setup
        if (isLoggedIn &&
            !hasProfile &&
            state.uri.toString() != '/profile-setup') {
          return '/profile-setup';
        }

        // If logged in with profile, redirect to home
        if (isLoggedIn &&
            hasProfile &&
            (state.uri.toString() == '/login' ||
                state.uri.toString() == '/register' ||
                state.uri.toString() == '/profile-setup')) {
          return '/home';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/', redirect: (context, state) => '/login'),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/profile-setup',
          builder: (context, state) => const ProfileSetupScreen(),
        ),
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/group',
          builder: (context, state) => const GroupScreen(),
        ),
        GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
      ],
    );
  }
}
