import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../utils/colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    debugPrint('🖱️ LoginScreen: _signInWithGoogle called');
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🖱️ LoginScreen: About to call authProvider.signInWithGoogle()');
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signInWithGoogle();
      debugPrint('🖱️ LoginScreen: authProvider.signInWithGoogle() completed successfully');
    } catch (e) {
      debugPrint('🚨 LoginScreen: Exception caught: $e');
      debugPrint('🚨 LoginScreen: Exception type: ${e.runtimeType}');
      debugPrint('🚨 LoginScreen: mounted = $mounted');
      if (mounted) {
        debugPrint('🚨 LoginScreen: Showing snackbar with error: ${e.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
        debugPrint('🚨 LoginScreen: Snackbar shown successfully');
      } else {
        debugPrint('🚨 LoginScreen: Widget not mounted - skipping snackbar');
      }
    } finally {
      debugPrint('🔄 LoginScreen: Finally block - mounted = $mounted');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        debugPrint('🔄 LoginScreen: Loading set to false');
      }
    }
  }

  @override
  void dispose() {
    debugPrint('🗑️ LoginScreen: Widget is being disposed!');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),

              // App Logo/Title
              Icon(
                Icons.groups,
                size: 80,
                color: AppColors.primary,
              ),
              
              const SizedBox(height: 24),

              Text(
                'LinkUp BU',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Boston University Students Only',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // BU Information Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.school,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Exclusive to BU Students',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'To access LinkUp BU, you must sign in with your Boston University Google account (@bu.edu)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Google Sign In Button
              GoogleSignInButton(
                onPressed: _signInWithGoogle,
                isLoading: _isLoading,
                width: double.infinity,
                height: 56,
                text: 'Sign in with BU Google Account',
              ),

              const SizedBox(height: 24),

              // Help Text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Need help?',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Make sure you\'re using your @bu.edu email address\n'
                      '• Your BU Google account is the same one you use for email and BU services\n'
                      '• Contact IT support if you\'re having trouble accessing your BU account',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}