import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/email_verification_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/colors.dart';

enum VerificationState { initial, emailSent, verifying, verified, error }

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();

  final EmailVerificationService _verificationService =
      EmailVerificationService();

  VerificationState _state = VerificationState.initial;
  String? _errorMessage;
  Timer? _resendTimer;
  int _resendCountdown = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkResendAvailability();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _emailFocusNode.dispose();
    _codeFocusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkResendAvailability() async {
    final canResend = await _verificationService.canResendCode();
    if (!canResend) {
      final countdown = await _verificationService.getResendCooldownSeconds();
      if (countdown > 0) {
        setState(() {
          _resendCountdown = countdown;
          _state = VerificationState.emailSent;
        });
        _startResendTimer();
      }
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendCountdown--;
      });

      if (_resendCountdown <= 0) {
        timer.cancel();
      }
    });
  }

  Future<void> _sendVerificationCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      await _verificationService.sendVerificationCode(email);

      setState(() {
        _state = VerificationState.emailSent;
        _resendCountdown = 60;
        _isLoading = false;
      });

      _startResendTimer();
      _codeFocusNode.requestFocus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification code sent to $email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = _verificationService.getDisplayErrorMessage(
          e.toString(),
        );
        _state = VerificationState.error;
        _isLoading = false;
      });
    }
  }

  Future<void> _validateCode() async {
    if (_codeController.text.trim().length != 6) {
      setState(() {
        _errorMessage = 'Please enter a 6-digit verification code';
        _state = VerificationState.error;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _state = VerificationState.verifying;
    });

    try {
      await _verificationService.validateCode(
        _codeController.text.trim(),
      );

      setState(() {
        _state = VerificationState.verified;
        _isLoading = false;
      });

      // Refresh the AuthProvider to get updated user data
      if (mounted) {
        await context.read<AuthProvider>().refreshCurrentUser();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email verified successfully! Welcome to LinkUp BU.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = _verificationService.getDisplayErrorMessage(
          e.toString(),
        );
        _state = VerificationState.error;
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await context.read<AuthProvider>().signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email address';
    }

    if (!_verificationService.isValidBUEmail(value)) {
      return 'Please enter a valid @bu.edu email address';
    }

    return null;
  }

  String? _validateCodeInput(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter the verification code';
    }

    if (value.length != 6) {
      return 'Verification code must be 6 digits';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'Verification code must contain only numbers';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, color: Colors.grey),
            label: const Text('Sign Out', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Header
                const Icon(
                  Icons.email_outlined,
                  size: 80,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),

                const Text(
                  'Verify Your BU Email',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                const Text(
                  'Please verify your Boston University email address to continue using LinkUp BU',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Email Input Section
                if (_state == VerificationState.initial ||
                    _state == VerificationState.error) ...[
                  TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    validator: _validateEmail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'BU Email Address',
                      hintText: 'yourname@bu.edu',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onFieldSubmitted: (_) => _sendVerificationCode(),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendVerificationCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
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
                            'Send Verification Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],

                // Code Input Section
                if (_state == VerificationState.emailSent ||
                    _state == VerificationState.verifying ||
                    _state == VerificationState.verified) ...[
                  // Success message
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Verification code sent to ${_emailController.text}',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _codeController,
                    focusNode: _codeFocusNode,
                    validator: _validateCodeInput,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 8,
                    ),
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Verification Code',
                      hintText: '123456',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: (value) {
                      if (value.length == 6) {
                        _validateCode();
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _validateCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
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
                        : Text(
                            _state == VerificationState.verified
                                ? 'Verified!'
                                : 'Verify Code',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Resend Button
                  TextButton(
                    onPressed: _resendCountdown > 0 || _isLoading
                        ? null
                        : () {
                            setState(() {
                              _state = VerificationState.initial;
                              _codeController.clear();
                            });
                          },
                    child: Text(
                      _resendCountdown > 0
                          ? 'Resend code in ${_resendCountdown}s'
                          : 'Resend code',
                      style: TextStyle(
                        color: _resendCountdown > 0
                            ? Colors.grey
                            : AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const Spacer(),

                // Help Text
                Text(
                  'Need help? Make sure you\'re using your official @bu.edu email address. Check your spam folder if you don\'t see the code.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
