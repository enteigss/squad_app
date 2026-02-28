import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailVerificationService {
  final FirebaseFunctions _functions;
  static const String _lastSentKey = 'email_verification_last_sent';

  EmailVerificationService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Send verification code to the provided email address
  /// Returns true if successful, throws exception if failed
  Future<bool> sendVerificationCode(String email) async {
    try {
      debugPrint('📧 EmailVerificationService: Sending verification code to $email');

      // Check rate limiting before making the call
      if (!await canResendCode()) {
        final remainingSeconds = await getResendCooldownSeconds();
        throw Exception('Please wait $remainingSeconds seconds before requesting another code');
      }

      final callable = _functions.httpsCallable('sendVerificationEmail');
      final result = await callable.call({
        'email': email,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        debugPrint('✅ EmailVerificationService: Verification email sent successfully');

        // Store the timestamp of when we sent the code
        await _storeLastSentTimestamp();

        return true;
      } else {
        debugPrint('❌ EmailVerificationService: Failed to send verification email: ${data['message']}');
        throw Exception(data['message'] ?? 'Failed to send verification email');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ EmailVerificationService: Firebase Functions error: ${e.code} - ${e.message}');

      // Handle specific error cases
      if (e.code == 'unauthenticated') {
        throw Exception('Please sign in to verify your email');
      } else if (e.message?.contains('Too many verification attempts') == true) {
        throw Exception('Too many verification attempts. Please try again later.');
      } else if (e.message?.contains('@bu.edu') == true) {
        throw Exception('Please enter a valid @bu.edu email address');
      } else {
        throw Exception(e.message ?? 'Failed to send verification email');
      }
    } catch (e) {
      debugPrint('❌ EmailVerificationService: Unexpected error: $e');
      if (e is Exception) rethrow;
      throw Exception('Failed to send verification email: $e');
    }
  }

  /// Validate the provided verification code
  /// Returns verification result with email if successful
  Future<Map<String, dynamic>> validateCode(String code) async {
    try {
      debugPrint('🔍 EmailVerificationService: Validating verification code');

      final callable = _functions.httpsCallable('validateVerificationCode');
      final result = await callable.call({
        'code': code.trim(),
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        debugPrint('✅ EmailVerificationService: Code validation successful');

        // Clear the rate limiting timestamp since verification was successful
        await _clearLastSentTimestamp();

        return {
          'success': true,
          'email': data['email'],
          'message': data['message'],
        };
      } else {
        debugPrint('❌ EmailVerificationService: Code validation failed: ${data['message']}');
        throw Exception(data['message'] ?? 'Invalid verification code');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ EmailVerificationService: Firebase Functions error: ${e.code} - ${e.message}');

      // Handle specific error cases with user-friendly messages
      if (e.code == 'unauthenticated') {
        throw Exception('Please sign in to verify your email');
      } else if (e.message?.contains('expired') == true) {
        throw Exception('Verification code has expired. Please request a new one.');
      } else if (e.message?.contains('attempts remaining') == true) {
        throw Exception(e.message!);
      } else if (e.message?.contains('Too many incorrect attempts') == true) {
        throw Exception('Too many incorrect attempts. Please request a new code.');
      } else if (e.message?.contains('No verification code found') == true) {
        throw Exception('No verification code found. Please request a new one.');
      } else {
        throw Exception(e.message ?? 'Failed to validate verification code');
      }
    } catch (e) {
      debugPrint('❌ EmailVerificationService: Unexpected error: $e');
      if (e is Exception) rethrow;
      throw Exception('Failed to validate verification code: $e');
    }
  }

  /// Check if user can resend verification code (rate limiting)
  /// Returns true if enough time has passed since last send
  Future<bool> canResendCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSentString = prefs.getString(_lastSentKey);

      if (lastSentString == null) {
        return true; // Never sent before
      }

      final lastSent = DateTime.parse(lastSentString);
      final now = DateTime.now();
      final difference = now.difference(lastSent);

      // Allow resend after 60 seconds
      return difference.inSeconds >= 60;
    } catch (e) {
      debugPrint('⚠️ EmailVerificationService: Error checking resend cooldown: $e');
      return true; // Default to allowing resend if we can't check
    }
  }

  /// Get remaining time in seconds before user can resend code
  Future<int> getResendCooldownSeconds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSentString = prefs.getString(_lastSentKey);

      if (lastSentString == null) {
        return 0; // No cooldown
      }

      final lastSent = DateTime.parse(lastSentString);
      final now = DateTime.now();
      final difference = now.difference(lastSent);
      final remaining = 60 - difference.inSeconds;

      return remaining > 0 ? remaining : 0;
    } catch (e) {
      debugPrint('⚠️ EmailVerificationService: Error calculating cooldown: $e');
      return 0; // Default to no cooldown if we can't calculate
    }
  }

  /// Store timestamp of when verification code was last sent
  Future<void> _storeLastSentTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSentKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('⚠️ EmailVerificationService: Error storing timestamp: $e');
    }
  }

  /// Clear the stored timestamp (called after successful verification)
  Future<void> _clearLastSentTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastSentKey);
    } catch (e) {
      debugPrint('⚠️ EmailVerificationService: Error clearing timestamp: $e');
    }
  }

  /// Check if email format is valid for BU verification
  bool isValidBUEmail(String email) {
    if (email.isEmpty) return false;

    final emailLower = email.toLowerCase().trim();
    return emailLower.endsWith('@bu.edu') && emailLower.contains('@');
  }

  /// Get formatted error message for UI display
  String getDisplayErrorMessage(String error) {
    // Convert technical errors to user-friendly messages
    if (error.contains('unauthenticated')) {
      return 'Please sign in to verify your email';
    } else if (error.contains('expired')) {
      return 'Code expired. Please request a new one.';
    } else if (error.contains('attempts remaining')) {
      return error; // Already formatted by server
    } else if (error.contains('Too many')) {
      return 'Too many attempts. Please try again later.';
    } else if (error.contains('@bu.edu')) {
      return 'Please enter a valid @bu.edu email address';
    } else if (error.contains('Invalid email')) {
      return 'Please enter a valid email address';
    } else {
      return error; // Return as-is for other errors
    }
  }

  /// Test function to verify service connectivity
  Future<void> testConnection() async {
    try {
      debugPrint('🧪 EmailVerificationService: Testing connection to Cloud Functions...');

      // This will fail but confirms the function is reachable
      await _functions.httpsCallable('sendVerificationEmail').call({
        'email': 'test-connection@invalid.com',
      });
    } catch (e) {
      debugPrint('✅ EmailVerificationService: Connection test complete (error expected): $e');
      // Error is expected - we just want to confirm the function is reachable
    }
  }
}