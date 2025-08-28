import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated {
    final authenticated = _currentUser != null;
    debugPrint(
      '🔐 AuthProvider.isAuthenticated: $authenticated (user: ${_currentUser?.id})',
    );
    return authenticated;
  }

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    debugPrint(
      '🚀 AuthProvider._initializeAuth: Setting up auth state listener',
    );
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        try {
          debugPrint('🔄 Auth state changed: User ${user.uid} signed in');
          debugPrint(
            '👤 Firebase User details: email=${user.email}, verified=${user.emailVerified}',
          );

          final userData = await _authService.getUserData(user.uid);
          debugPrint('📊 User data from Firestore: ${userData?.toMap()}');

          _currentUser = userData;
          debugPrint(
            '✅ AuthProvider._currentUser updated: ${_currentUser != null}',
          );
          notifyListeners();
        } catch (e) {
          debugPrint('❌ Error getting user data: $e');
          debugPrint('🔍 Error type: ${e.runtimeType}');
          _error = e.toString();
          notifyListeners();
        }
      } else {
        debugPrint('🔄 Auth state changed: User signed out');
        _currentUser = null;
        debugPrint('🚪 AuthProvider._currentUser set to null');
        notifyListeners();
      }
    });
  }

  Future<void> signInWithGoogle() async {
    try {
      debugPrint('🔑 AuthProvider.signInWithGoogle: Starting Google sign-in');
      _setLoading(true);
      _clearError();

      final isNewUser = _currentUser == null;
      debugPrint('👶 Is new user: $isNewUser');

      debugPrint(
        '📞 AuthProvider: About to call AuthService.signInWithGoogle()',
      );
      final signInResult = await _authService.signInWithGoogle();
      debugPrint(
        '📞 AuthProvider: AuthService.signInWithGoogle() completed successfully',
      );
      debugPrint(
        '📝 Sign-in result from AuthService: ${signInResult?.toMap()}',
      );
      _currentUser = signInResult;

      if (_currentUser == null) {
        debugPrint(
          '❌ AuthProvider.signInWithGoogle: _currentUser is null after sign-in',
        );
        throw Exception('Failed to sign in with Google');
      }

      debugPrint(
        '✅ AuthProvider.signInWithGoogle: Sign-in successful for user ${_currentUser!.id}',
      );

      // Track signup for new users, login for returning users
      if (isNewUser) {
        await AnalyticsService().trackUserSignup(
          method: 'google',
          userId: _currentUser!.id,
        );

        // Set user properties for analytics
        await AnalyticsService().setUserId(_currentUser!.id);
        await AnalyticsService().setUserProperties(
          signupDate: DateTime.now().toIso8601String().split('T')[0],
          gender: _currentUser!.gender,
        );
      } else {
        await AnalyticsService().trackLogin(
          method: 'google',
          userId: _currentUser!.id,
        );
      }
    } catch (e) {
      debugPrint('🚨 AuthProvider.signInWithGoogle: Exception caught: $e');
      debugPrint('🚨 AuthProvider: Exception type: ${e.runtimeType}');
      _error = _getErrorMessage(e);
      debugPrint('🚨 AuthProvider: Processed error message: $_error');
      debugPrint('🚨 AuthProvider: About to rethrow exception to LoginScreen');
      rethrow;
    } finally {
      debugPrint('🔄 AuthProvider: Finally block - setting loading to false');
      _setLoading(false);
    }
  }


  Future<void> signOut() async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.signOut();

      // Reset analytics first-time flags for new user session
      AnalyticsService().resetFirstTimeFlags();

      _currentUser = null;
    } catch (e) {
      _error = _getErrorMessage(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
    String? bio,
    int? age,
    String? location,
    List<String>? interests,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.updateUserProfile(
        displayName: displayName,
        photoUrl: photoUrl,
        bio: bio,
        age: age,
        location: location,
        interests: interests,
      );

      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          displayName: displayName ?? _currentUser!.displayName,
          photoUrl: photoUrl ?? _currentUser!.photoUrl,
          bio: bio ?? _currentUser!.bio,
          age: age ?? _currentUser!.age,
          location: location ?? _currentUser!.location,
          interests: interests ?? _currentUser!.interests,
          hasCreatedProfile: true,
        );
        notifyListeners();
      }
    } catch (e) {
      _error = _getErrorMessage(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateCurrentUser(UserModel updatedUser) async {
    _currentUser = updatedUser;
    notifyListeners();
  }

  Future<bool> checkUsernameAvailability(String username) async {
    try {
      return await _authService.isUsernameAvailable(username);
    } catch (e) {
      _error = _getErrorMessage(e);
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email address.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'email-already-in-use':
          return 'An account already exists with this email address.';
        case 'weak-password':
          return 'Password is too weak. Please choose a stronger password.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'operation-not-allowed':
          return 'This operation is not allowed.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        default:
          return error.message ?? 'An authentication error occurred.';
      }
    }

    // Handle regular exceptions by extracting just the message
    String errorMessage = error.toString();
    if (errorMessage.startsWith('Exception: ')) {
      return errorMessage.substring('Exception: '.length);
    }
    return errorMessage;
  }

  Future<void> updateAvailability(
    Map<String, Map<String, bool>> availability,
  ) async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.updateUserAvailability(availability: availability);

      // Update the current user model to reflect completed profile
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(profileCompleted: true);
        notifyListeners();
      }
    } catch (e) {
      _error = _getErrorMessage(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateSquadsOptIn(bool optIn) async {
    try {
      await _authService.updateSquadsOptIn(optIn);

      // Update the current user model to reflect the change
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(squadsOptIn: optIn);
        notifyListeners();
      }
    } catch (e) {
      _error = _getErrorMessage(e);
      rethrow;
    }
  }

  Future<void> updatePreferences({
    Map<String, int>? importanceRatings,
    String? personalityType,
    String? hangoutFrequency,
    String? conversationStyle,
    String? socialInteractionPreference,
    List<String>? genderPreferences,
    Map<String, Map<String, int>>? activityPreferences,
    String? userGender,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.updateUserPreferences(
        importanceRatings: importanceRatings,
        personalityType: personalityType,
        hangoutFrequency: hangoutFrequency,
        conversationStyle: conversationStyle,
        socialInteractionPreference: socialInteractionPreference,
        genderPreferences: genderPreferences,
        activityPreferences: activityPreferences,
        userGender: userGender,
      );

      // Update the current user model to reflect completed preferences
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          hasCompletedPreferences: true,
          gender: userGender ?? _currentUser!.gender,
        );
        notifyListeners();
      }
    } catch (e) {
      _error = _getErrorMessage(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
}
