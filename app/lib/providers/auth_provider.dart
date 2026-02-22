import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/matching_profile.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/account_deletion_service.dart';
import '../services/storage_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final AccountDeletionService _deletionService = AccountDeletionService();
  final StorageService _storageService = StorageService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _accountDeletionCompleted = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get accountDeletionCompleted => _accountDeletionCompleted;
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

          // Request notification permissions for returning users
          try {
            debugPrint(
              '🔔 Requesting notification permissions for returning user...',
            );
            final notificationService = NotificationService();
            await notificationService.requestPermission();
            debugPrint(
              '✅ Notification permissions requested successfully for returning user',
            );

            // Unsubscribe from hangout topics then subscribe based on gender
            debugPrint(
              '🔕 Unsubscribing from all hangout notification topics...',
            );
            await notificationService.unsubscribeFromTopics([
              'new_hangouts_bu_men',
              'new_hangouts_bu_women',
              'new_hangouts_bu_anyone',
            ]);
            debugPrint(
              '✅ Successfully unsubscribed from all hangout topics for returning user',
            );

            // Subscribe to appropriate topics based on user gender
            debugPrint(
              '🔔 Subscribing to hangout topics based on gender: ${userData?.gender}',
            );
            await notificationService.subscribeToHangoutTopicsBasedOnGender(
              userData?.gender,
            );
            debugPrint(
              '✅ Successfully subscribed to appropriate hangout topics for returning user',
            );
          } catch (e) {
            debugPrint(
              '⚠️ Warning: Failed to setup notifications for returning user: $e',
            );
            // Don't fail the auth state change if notification setup fails
          }

          debugPrint('AuthProvider notifying listeners');
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

      // Reset account deletion flag on successful sign in
      _accountDeletionCompleted = false;

      if (_currentUser == null) {
        debugPrint(
          '❌ AuthProvider.signInWithGoogle: _currentUser is null after sign-in',
        );
        throw Exception('Failed to sign in with Google');
      }

      debugPrint(
        '✅ AuthProvider.signInWithGoogle: Sign-in successful for user ${_currentUser!.id}',
      );

      // Request notification permissions and get FCM token
      try {
        debugPrint('🔔 Requesting notification permissions...');
        final notificationService = NotificationService();
        await notificationService.requestPermission();
        debugPrint('✅ Notification permissions requested successfully');

        // Unsubscribe from hangout topics then subscribe based on gender
        debugPrint('🔕 Unsubscribing from all hangout notification topics...');
        await notificationService.unsubscribeFromTopics([
          'new_hangouts_bu_men',
          'new_hangouts_bu_women',
          'new_hangouts_bu_anyone',
        ]);
        debugPrint('✅ Successfully unsubscribed from all hangout topics');

        // Subscribe to appropriate topics based on user gender
        debugPrint(
          '🔔 Subscribing to hangout topics based on gender: ${_currentUser?.gender}',
        );
        await notificationService.subscribeToHangoutTopicsBasedOnGender(
          _currentUser?.gender,
        );
        debugPrint('✅ Successfully subscribed to appropriate hangout topics');
      } catch (e) {
        debugPrint('⚠️ Warning: Failed to setup notifications: $e');
        // Don't fail the sign-in process if notification setup fails
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

  Future<void> signInWithApple() async {
    try {
      debugPrint('🍎 AuthProvider.signInWithApple: Starting Apple sign-in');
      _setLoading(true);
      _clearError();

      final isNewUser = _currentUser == null;
      debugPrint('👶 Is new user: $isNewUser');

      debugPrint(
        '📞 AuthProvider: About to call AuthService.signInWithApple()',
      );
      final signInResult = await _authService.signInWithApple();
      debugPrint(
        '📞 AuthProvider: AuthService.signInWithApple() completed successfully',
      );
      debugPrint(
        '📝 Apple sign-in result from AuthService: ${signInResult?.toMap()}',
      );
      _currentUser = signInResult;

      // Reset account deletion flag on successful sign in
      _accountDeletionCompleted = false;

      if (_currentUser == null) {
        debugPrint(
          '❌ AuthProvider.signInWithApple: _currentUser is null after sign-in',
        );
        throw Exception('Failed to sign in with Apple');
      }

      debugPrint(
        '✅ AuthProvider.signInWithApple: Sign-in successful for user ${_currentUser!.id}',
      );

      // Check if user needs email verification
      if (!_currentUser!.isEmailVerified) {
        debugPrint(
          '📧 User needs email verification - navigation will be handled by GoRouter redirect',
        );
        // GoRouter will automatically redirect to /email-verification based on isEmailVerified status
      }

      // Request notification permissions and get FCM token
      try {
        debugPrint('🔔 Requesting notification permissions for Apple user...');
        final notificationService = NotificationService();
        await notificationService.requestPermission();
        debugPrint(
          '✅ Notification permissions requested successfully for Apple user',
        );

        // Unsubscribe from hangout topics then subscribe based on gender
        debugPrint('🔕 Unsubscribing from all hangout notification topics...');
        await notificationService.unsubscribeFromTopics([
          'new_hangouts_bu_men',
          'new_hangouts_bu_women',
          'new_hangouts_bu_anyone',
        ]);
        debugPrint(
          '✅ Successfully unsubscribed from all hangout topics for Apple user',
        );

        // Subscribe to appropriate topics based on user gender
        debugPrint(
          '🔔 Subscribing to hangout topics based on gender: ${_currentUser?.gender}',
        );
        await notificationService.subscribeToHangoutTopicsBasedOnGender(
          _currentUser?.gender,
        );
        debugPrint(
          '✅ Successfully subscribed to appropriate hangout topics for Apple user',
        );
      } catch (e) {
        debugPrint(
          '⚠️ Warning: Failed to setup notifications for Apple user: $e',
        );
        // Don't fail the sign-in process if notification setup fails
      }

    } catch (e) {
      debugPrint('🚨 AuthProvider.signInWithApple: Exception caught: $e');
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

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('📧 AuthProvider.signInWithEmailPassword: Starting email/password sign-in');
      _setLoading(true);
      _clearError();

      debugPrint(
        '📞 AuthProvider: About to call AuthService.signInWithEmailAndPassword()',
      );
      final signInResult = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint(
        '📞 AuthProvider: AuthService.signInWithEmailAndPassword() completed successfully',
      );
      debugPrint(
        '📝 Email/password sign-in result from AuthService: ${signInResult?.toMap()}',
      );
      _currentUser = signInResult;

      // Reset account deletion flag on successful sign in
      _accountDeletionCompleted = false;

      if (_currentUser == null) {
        debugPrint(
          '❌ AuthProvider.signInWithEmailPassword: _currentUser is null after sign-in',
        );
        throw Exception('Failed to sign in with email and password');
      }

      debugPrint(
        '✅ AuthProvider.signInWithEmailPassword: Sign-in successful for user ${_currentUser!.id}',
      );

      // Request notification permissions and get FCM token
      try {
        debugPrint('🔔 Requesting notification permissions...');
        final notificationService = NotificationService();
        await notificationService.requestPermission();
        debugPrint('✅ Notification permissions requested successfully');

        // Unsubscribe from hangout topics then subscribe based on gender
        debugPrint('🔕 Unsubscribing from all hangout notification topics...');
        await notificationService.unsubscribeFromTopics([
          'new_hangouts_bu_men',
          'new_hangouts_bu_women',
          'new_hangouts_bu_anyone',
        ]);
        debugPrint('✅ Successfully unsubscribed from all hangout topics');

        // Subscribe to appropriate topics based on user gender
        debugPrint(
          '🔔 Subscribing to hangout topics based on gender: ${_currentUser?.gender}',
        );
        await notificationService.subscribeToHangoutTopicsBasedOnGender(
          _currentUser?.gender,
        );
        debugPrint('✅ Successfully subscribed to appropriate hangout topics');
      } catch (e) {
        debugPrint('⚠️ Warning: Failed to setup notifications: $e');
        // Don't fail the sign-in process if notification setup fails
      }

    } catch (e) {
      debugPrint('🚨 AuthProvider.signInWithEmailPassword: Exception caught: $e');
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

      // Remove FCM token before signing out
      try {
        debugPrint('🔔 Removing FCM token before sign out...');
        final notificationService = NotificationService();
        await notificationService.removeToken();
        debugPrint('✅ FCM token removed successfully');
      } catch (e) {
        debugPrint('⚠️ Warning: Failed to remove FCM token: $e');
        // Don't fail the sign out process if token removal fails
      }

      await _authService.signOut();


      _currentUser = null;
      notifyListeners(); // Ensure UI is updated immediately after sign out
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
    String? classYear,
    String? location,
    List<String>? interests,
    String? gender,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Track if gender is changing for notification topic updates
      final previousGender = _currentUser?.gender;
      final isGenderChanging = gender != null && gender != previousGender;

      // Handle photo URL changes
      String? finalPhotoUrl = photoUrl;
      if (photoUrl != null) {
        // If photoUrl is empty string, user wants to remove photo
        if (photoUrl.isEmpty) {
          // Delete old photo if it exists
          if (_currentUser?.photoUrl != null && _currentUser!.photoUrl!.isNotEmpty) {
            try {
              await _storageService.deleteOldProfileImage(_currentUser!.photoUrl);
            } catch (e) {
              debugPrint('Warning: Failed to delete old profile image: $e');
            }
          }
          finalPhotoUrl = null;
        } else {
          // New photo URL provided - delete old one if different
          if (_currentUser?.photoUrl != null && 
              _currentUser!.photoUrl!.isNotEmpty && 
              _currentUser!.photoUrl != photoUrl) {
            try {
              await _storageService.deleteOldProfileImage(_currentUser!.photoUrl);
            } catch (e) {
              debugPrint('Warning: Failed to delete old profile image: $e');
            }
          }
        }
      }

      await _authService.updateUserProfile(
        displayName: displayName,
        photoUrl: finalPhotoUrl,
        bio: bio,
        classYear: classYear,
        location: location,
        interests: interests,
        gender: gender,
      );

      // Update local user model
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          displayName: displayName,
          photoUrl: finalPhotoUrl,
          bio: bio,
          classYear: classYear,
          location: location,
          interests: interests,
          gender: gender,
        );
      }

      // If gender changed, update notification topic subscriptions
      if (isGenderChanging) {
        try {
          debugPrint(
            '🔔 Gender changed from $previousGender to $gender, updating notification topics...',
          );
          final notificationService = NotificationService();

          // Unsubscribe from all hangout topics first
          await notificationService.unsubscribeFromTopics([
            'new_hangouts_bu_men',
            'new_hangouts_bu_women',
            'new_hangouts_bu_nonbinary',
            'new_hangouts_all_genders',
          ]);

          // Subscribe to appropriate topics based on new gender
          await notificationService.subscribeToHangoutTopicsBasedOnGender(
            gender,
          );
          debugPrint(
            '✅ Successfully updated notification topics for new gender',
          );
        } catch (e) {
          debugPrint(
            '⚠️ Warning: Failed to update notification topics after gender change: $e',
          );
          // Don't fail the profile update if notification setup fails
        }
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

  // Method to refresh user data from Firestore (useful after subscription changes)
  Future<void> refreshCurrentUser() async {
    if (_currentUser != null) {
      try {
        final userData = await _authService.getUserData(_currentUser!.id);
        if (userData != null) {
          _currentUser = userData;
          notifyListeners();
          debugPrint('✅ Current user data refreshed from Firestore');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to refresh current user data: $e');
      }
    }
  }

  /// Update the user's matching profile
  Future<void> updateMatchingProfile(MatchingProfile profile) async {
    if (_currentUser == null) {
      throw Exception('No user logged in');
    }

    try {
      debugPrint('📝 Updating matching profile for user ${_currentUser!.id}');

      final profileWithTimestamp = MatchingProfile(
        isActive: profile.isActive,
        genderPreference: profile.genderPreference,
        funActivities: profile.funActivities,
        talkAboutForever: profile.talkAboutForever,
        freeTime: profile.freeTime,
        activityRatings: profile.activityRatings,
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.id)
          .update({
        'matchingProfile': profileWithTimestamp.toMap(),
      });

      // Update local user model
      _currentUser = _currentUser!.copyWith(
        matchingProfile: profileWithTimestamp,
      );
      notifyListeners();

      debugPrint('✅ Matching profile updated successfully');
    } catch (e) {
      debugPrint('❌ Failed to update matching profile: $e');
      rethrow;
    }
  }

  /// Toggle the matching profile active status
  Future<void> toggleMatchingActive(bool isActive) async {
    if (_currentUser == null || _currentUser!.matchingProfile == null) {
      throw Exception('No matching profile found');
    }

    try {
      debugPrint('🔄 Toggling matching active to: $isActive');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.id)
          .update({
        'matchingProfile.isActive': isActive,
        'matchingProfile.updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Update local user model
      final updatedProfile = _currentUser!.matchingProfile!.copyWith(
        isActive: isActive,
        updatedAt: DateTime.now(),
      );
      _currentUser = _currentUser!.copyWith(
        matchingProfile: updatedProfile,
      );
      notifyListeners();

      debugPrint('✅ Matching active status updated to: $isActive');
    } catch (e) {
      debugPrint('❌ Failed to toggle matching active: $e');
      rethrow;
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

  void resetAccountDeletionFlag() {
    _accountDeletionCompleted = false;
    notifyListeners();
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

  /// Re-authenticate user for sensitive operations like account deletion
  Future<bool> reauthenticateUser() async {
    try {
      _setLoading(true);
      _clearError();

      final success = await _authService.reauthenticateUser();
      if (!success) {
        _error = 'Re-authentication failed';
      }
      return success;
    } catch (e) {
      _error = _getErrorMessage(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Check if user has active subscriptions
  Future<bool> hasActiveSubscriptions() async {
    if (_currentUser == null) return false;

    try {
      return await _deletionService.hasActiveSubscriptions(_currentUser!.id);
    } catch (e) {
      debugPrint('Error checking subscriptions: $e');
      return false;
    }
  }

  /// Delete user account with progress updates
  Stream<String> deleteAccount() async* {
    if (_currentUser == null) {
      yield 'Error: No user found';
      return;
    }

    try {
      debugPrint('🗑️ AuthProvider: Starting account deletion process');


      // Stream deletion progress
      await for (final step in _deletionService.deleteUserAccount(
        _currentUser!.id,
      )) {
        yield step;
      }

      // Clear local state FIRST before setting deletion flag
      // This ensures isAuthenticated becomes false immediately
      _currentUser = null;

      // Now set deletion completed flag and notify listeners once
      _accountDeletionCompleted = true;
      debugPrint(
        '🚨 AuthProvider: About to call notifyListeners() after account deletion - this will trigger redirect',
      );
      notifyListeners();


      debugPrint('✅ AuthProvider: Account deletion completed successfully');
    } catch (e) {
      debugPrint('❌ AuthProvider: Account deletion failed: $e');


      yield 'Account deletion failed: $e';
      rethrow;
    }
  }

  /// Schedule account deletion for future date
  Future<void> scheduleAccountDeletion(DateTime deletionDate) async {
    if (_currentUser == null) return;

    try {
      _setLoading(true);
      _clearError();

      await _deletionService.scheduleAccountDeletion(
        _currentUser!.id,
        deletionDate,
      );


      debugPrint('✅ Account deletion scheduled for $deletionDate');
    } catch (e) {
      _error = _getErrorMessage(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Cancel scheduled account deletion
  Future<void> cancelScheduledDeletion() async {
    if (_currentUser == null) return;

    try {
      _setLoading(true);
      _clearError();

      await _deletionService.cancelScheduledDeletion(_currentUser!.id);


      debugPrint('✅ Scheduled account deletion cancelled');
    } catch (e) {
      _error = _getErrorMessage(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
}
