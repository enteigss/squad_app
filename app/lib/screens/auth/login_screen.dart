import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../widgets/apple_sign_in_button.dart';
import '../../utils/colors.dart';
import '../../utils/url_launcher_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isEmailLoading = false;
  bool _showEmailPasswordFields = false;
  int _logoTapCount = 0;
  DateTime? _lastTapTime;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogoTap() {
    final now = DateTime.now();

    // Reset counter if more than 2 seconds since last tap
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _logoTapCount = 1;
    } else {
      _logoTapCount++;
    }

    _lastTapTime = now;

    // Show debug fields after 5 taps
    if (_logoTapCount >= 5 && !_showEmailPasswordFields) {
      setState(() {
        _showEmailPasswordFields = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App Review login enabled'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _signInWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isEmailLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signInWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEmailLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithApple() async {
    debugPrint('🍎 LoginScreen: _signInWithApple called');
    setState(() {
      _isAppleLoading = true;
    });

    try {
      debugPrint(
        '🍎 LoginScreen: About to call authProvider.signInWithApple()',
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signInWithApple();
      debugPrint(
        '🍎 LoginScreen: authProvider.signInWithApple() completed successfully',
      );
    } catch (e) {
      debugPrint('🚨 LoginScreen: Apple Sign In Exception caught: $e');
      debugPrint('🚨 LoginScreen: Exception type: ${e.runtimeType}');
      debugPrint('🚨 LoginScreen: mounted = $mounted');
      if (mounted) {
        debugPrint(
          '🚨 LoginScreen: Showing snackbar with error: ${e.toString()}',
        );
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
      debugPrint(
        '🔄 LoginScreen: Apple Sign In finally block - mounted = $mounted',
      );
      if (mounted) {
        setState(() {
          _isAppleLoading = false;
        });
        debugPrint('🔄 LoginScreen: Apple loading set to false');
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    debugPrint('🖱️ LoginScreen: _signInWithGoogle called');
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      debugPrint(
        '🖱️ LoginScreen: About to call authProvider.signInWithGoogle()',
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signInWithGoogle();
      debugPrint(
        '🖱️ LoginScreen: authProvider.signInWithGoogle() completed successfully',
      );
    } catch (e) {
      debugPrint('🚨 LoginScreen: Exception caught: $e');
      debugPrint('🚨 LoginScreen: Exception type: ${e.runtimeType}');
      debugPrint('🚨 LoginScreen: mounted = $mounted');
      if (mounted) {
        debugPrint(
          '🚨 LoginScreen: Showing snackbar with error: ${e.toString()}',
        );
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
          _isGoogleLoading = false;
        });
        debugPrint('🔄 LoginScreen: Google loading set to false');
      }
    }
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

              // App Logo/Title (tap 5 times to reveal email/password login)
              GestureDetector(
                onTap: _handleLogoTap,
                child: Image.asset(
                  'assets/images/linkup_logo_300.png',
                  width: 100,
                  height: 100,
                ),
              ),

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
                    Icon(Icons.school, color: AppColors.primary, size: 32),
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
                      'To access LinkUp BU, you must be a Boston University student. If signing in with Google, use your @bu.edu email address.',
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
                onPressed: _isAppleLoading ? null : _signInWithGoogle,
                isLoading: _isGoogleLoading,
                width: double.infinity,
                height: 56,
                text: 'Sign in with BU Google Account',
              ),

              const SizedBox(height: 16),

              // Apple Sign In Button
              AppleSignInButton(
                onPressed: _isGoogleLoading ? null : _signInWithApple,
                isLoading: _isAppleLoading,
                width: double.infinity,
                height: 56,
                text: 'Sign in with Apple',
              ),

              // Email/Password fields (hidden until logo tapped 5 times)
              if (_showEmailPasswordFields) ...[
                const SizedBox(height: 32),

                // Divider with text
                Row(
                  children: [
                    const Expanded(
                      child: Divider(color: AppColors.textSecondary),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'App Review Access',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(color: AppColors.textSecondary),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Sign in button
                      ElevatedButton(
                        onPressed: _isEmailLoading
                            ? null
                            : _signInWithEmailPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isEmailLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],

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
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
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

              // Privacy Policy Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'By signing in, you agree to our ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final success =
                          await UrlLauncherHelper.launchPrivacyPolicy();
                      if (!success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open privacy policy'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
                    child: Text(
                      'Privacy Policy',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
