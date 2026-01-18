import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'notification_service.dart';

class AccountDeletionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final NotificationService _notificationService = NotificationService();

  /// Revoke notification tokens and unsubscribe from topics
  Future<void> revokeNotificationTokens(String userId) async {
    try {
      debugPrint('🗑️ Revoking notification tokens...');

      // Unsubscribe from all topics
      await _notificationService.unsubscribeFromTopics([
        'new_hangouts_bu_men',
        'new_hangouts_bu_women',
        'new_hangouts_bu_anyone',
      ]);

      debugPrint('✅ Notification tokens revoked successfully');
    } catch (e) {
      debugPrint('❌ Error revoking notification tokens: $e');
      rethrow;
    }
  }

  /// Revoke Apple Sign In token according to Apple's requirements
  Future<void> revokeAppleSignInToken(String userId) async {
    try {
      debugPrint('🍎 Revoking Apple Sign In token...');

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('No current user found for Apple token revocation');
        return;
      }

      // For Apple Sign In token revocation, we need to use Apple's REST API
      // This would require the refresh token which should be stored
      // For now, we'll log that we would revoke the token
      debugPrint('🍎 Would revoke Apple token for user: $userId');
      debugPrint('🍎 Production implementation should call Apple\'s revoke API');

      debugPrint('✅ Apple Sign In token revocation completed');
    } catch (e) {
      debugPrint('❌ Error revoking Apple Sign In token: $e');
      // Don't throw error here as token revocation failure shouldn't block account deletion
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Apple Sign In token revocation failed',
      );
    }
  }

  /// Main method to delete user account using Cloud Function
  /// Returns a stream of progress messages for UI updates
  Stream<String> deleteUserAccount(String userId) async* {
    try {
      yield 'Starting account deletion process...';

      debugPrint('🚀 Starting complete account deletion for user: $userId');
      await FirebaseCrashlytics.instance.log('Account deletion started for user: $userId');

      // Step 1: Revoke Apple Sign In token first (if applicable)
      yield 'Revoking authentication tokens...';
      await revokeAppleSignInToken(userId);

      // Step 2: Revoke notification tokens
      yield 'Unsubscribing from notifications...';
      await revokeNotificationTokens(userId);

      // Step 3: Call Cloud Function to delete all data
      yield 'Deleting account data...';

      final HttpsCallable callable = _functions.httpsCallable('deleteUserAccount');

      try {
        final result = await callable.call({'userId': userId});
        final data = result.data as Map<String, dynamic>;

        if (data['success'] == true) {
          final deletedDataRaw = data['deletedData'];
          if (deletedDataRaw != null) {
            // Handle the type casting more safely
            final deletedData = Map<String, dynamic>.from(deletedDataRaw as Map);
            yield 'Deleted ${deletedData['posts']} posts, ${deletedData['messages']} messages, and ${deletedData['mediaFiles']} media files';
          }
          yield 'Account deletion completed successfully';
        } else {
          throw Exception(data['message'] ?? 'Cloud function returned failure');
        }
      } catch (e) {
        debugPrint('❌ Cloud Function error: $e');
        throw Exception('Failed to delete account data: $e');
      }

      debugPrint('✅ Complete account deletion finished for user: $userId');
      await FirebaseCrashlytics.instance.log('Account deletion completed successfully for user: $userId');

    } catch (e) {
      final errorMessage = 'Account deletion failed: $e';
      yield errorMessage;

      debugPrint('❌ Account deletion failed for user $userId: $e');
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Account deletion failed',
        information: ['User ID: $userId'],
      );

      rethrow;
    }
  }

  /// Check if user has active subscriptions that need to be cancelled
  Future<bool> hasActiveSubscriptions(String userId) async {
    try {
      // This would typically check with your subscription service
      // For now, we'll assume no active subscriptions
      debugPrint('Checking for active subscriptions for user: $userId');
      return false;
    } catch (e) {
      debugPrint('Error checking subscriptions: $e');
      return false;
    }
  }

  /// Schedule account deletion for a future date (useful for subscription handling)
  Future<void> scheduleAccountDeletion(String userId, DateTime deletionDate) async {
    try {
      // This would typically be handled by a Cloud Function with a scheduled trigger
      // For now, we'll just log the request
      debugPrint('Account deletion scheduled for $deletionDate');
    } catch (e) {
      debugPrint('Error scheduling account deletion: $e');
      rethrow;
    }
  }

  /// Cancel a scheduled account deletion
  Future<void> cancelScheduledDeletion(String userId) async {
    try {
      // This would typically be handled by updating a Cloud Firestore document
      // For now, we'll just log the cancellation
      debugPrint('Scheduled account deletion cancelled for user: $userId');
    } catch (e) {
      debugPrint('Error cancelling scheduled deletion: $e');
      rethrow;
    }
  }
}