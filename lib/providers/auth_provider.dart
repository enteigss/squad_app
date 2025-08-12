import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        try {
          print('🔄 Auth state changed: User ${user.uid} signed in');
          _currentUser = await _authService.getUserData(user.uid);
          print('📊 User data from Firestore: ${_currentUser?.toMap()}');
          notifyListeners();
        } catch (e) {
          print('❌ Error getting user data: $e');
          _error = e.toString();
          notifyListeners();
        }
      } else {
        print('🔄 Auth state changed: User signed out');
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      _currentUser = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (_currentUser == null) {
        throw Exception('Failed to sign in');
      }
    } catch (e) {
      _error = _getErrorMessage(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    try {
      _setLoading(true);
      _clearError();

      _currentUser = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (_currentUser == null) {
        throw Exception('Failed to create account');
      }
    } catch (e) {
      _error = _getErrorMessage(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      _setLoading(true);
      _clearError();

      _currentUser = await _authService.signInWithGoogle();

      if (_currentUser == null) {
        throw Exception('Failed to sign in with Google');
      }
    } catch (e) {
      _error = _getErrorMessage(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.signOut();
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

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.sendPasswordResetEmail(email);
    } catch (e) {
      _error = _getErrorMessage(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
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
    return error.toString();
  }

  Future<void> updateAvailability(Map<String, Map<String, bool>> availability) async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.updateUserAvailability(availability: availability);

      // Update the current user model to reflect completed profile
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          profileCompleted: true,
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

  Future<void> updatePreferences({
    Map<String, int>? importanceRatings,
    String? personalityType,
    String? hangoutFrequency,
    String? conversationStyle,
    String? socialInteractionPreference,
    List<String>? genderPreferences,
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
      );

      // Update the current user model to reflect completed preferences
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          hasCompletedPreferences: true,
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
