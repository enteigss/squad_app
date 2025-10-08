import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/navigation_service.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('User granted permission');
      }
      // Permission granted, now get the token
      await getToken();
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      if (kDebugMode) {
        print('User granted provisional permission');
      }
    } else {
      if (kDebugMode) {
        print('User declined or has not accepted permission');
      }
      // You could show a gentle reminder or guide them to settings
    }
  }

  Future<void> getToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        if (kDebugMode) {
          print('FCM Token: $token');
        }

        // Save token to Firebase
        await _saveTokenToFirebase(token);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
    }
  }

  Future<void> _saveTokenToFirebase(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update the user's FCM token in Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });

        if (kDebugMode) {
          print('FCM token saved to Firebase for user: ${user.uid}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving FCM token to Firebase: $e');
      }
    }
  }

  // Method to refresh token when it changes
  Future<void> onTokenRefresh() async {
    _firebaseMessaging.onTokenRefresh.listen((String token) async {
      if (kDebugMode) {
        print('FCM Token refreshed: $token');
      }

      // Save the new token to Firebase
      await _saveTokenToFirebase(token);
    });
  }

  // Initialize token refresh listener
  void initializeTokenRefresh() {
    onTokenRefresh();
  }

  // Method to remove FCM token when user signs out
  Future<void> removeToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Remove the FCM token from Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });

        if (kDebugMode) {
          print('FCM token removed from Firebase for user: ${user.uid}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error removing FCM token from Firebase: $e');
      }
    }
  }

  // Method to get current token (useful for debugging)
  Future<String?> getCurrentToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current FCM token: $e');
      }
      return null;
    }
  }

  // Method to check if user has granted notification permissions
  Future<bool> hasPermission() async {
    try {
      final settings = await _firebaseMessaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking notification permissions: $e');
      }
      return false;
    }
  }

  // Method to unsubscribe from a specific topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        print('Successfully unsubscribed from topic: $topic');
      }

      // Update user's subscribed topics in Firestore
      final currentTopics = await _getSubscribedTopicsFromFirestore();
      if (currentTopics.contains(topic)) {
        currentTopics.remove(topic);
        await _updateSubscribedTopicsInFirestore(currentTopics);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unsubscribing from topic $topic: $e');
      }
      // Don't throw error - this shouldn't block the user flow
    }
  }

  // Method to unsubscribe from multiple topics
  Future<void> unsubscribeFromTopics(List<String> topics) async {
    if (kDebugMode) {
      print('Unsubscribing from topics: ${topics.join(", ")}');
    }

    // Unsubscribe from FCM topics
    for (final topic in topics) {
      try {
        await _firebaseMessaging.unsubscribeFromTopic(topic);
        if (kDebugMode) {
          print('Successfully unsubscribed from topic: $topic');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error unsubscribing from topic $topic: $e');
        }
      }
    }

    // Update Firestore to remove these topics
    final currentTopics = await _getSubscribedTopicsFromFirestore();
    final updatedTopics = currentTopics
        .where((topic) => !topics.contains(topic))
        .toList();
    await _updateSubscribedTopicsInFirestore(updatedTopics);

    if (kDebugMode) {
      print('Completed unsubscribing from ${topics.length} topics');
    }
  }

  // Method to subscribe to a specific topic (for future use)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      if (kDebugMode) {
        print('Successfully subscribed to topic: $topic');
      }

      // Update user's subscribed topics in Firestore
      final currentTopics = await _getSubscribedTopicsFromFirestore();
      if (!currentTopics.contains(topic)) {
        currentTopics.add(topic);
        await _updateSubscribedTopicsInFirestore(currentTopics);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to topic $topic: $e');
      }
      // Don't throw error - this shouldn't block the user flow
    }
  }

  // Method to subscribe to hangout topics based on user gender
  Future<void> subscribeToHangoutTopicsBasedOnGender(String? gender) async {
    if (kDebugMode) {
      print('Subscribing to hangout topics for gender: ${gender ?? "null"}');
    }

    List<String> topics = [];

    // Subscribe to appropriate topics based on user's gender
    if (gender?.toLowerCase() == 'man') {
      topics.addAll(['new_hangouts_bu_men', 'new_hangouts_all_genders']);
    } else if (gender?.toLowerCase() == 'woman') {
      topics.addAll(['new_hangouts_bu_women', 'new_hangouts_all_genders']);
    } else if (gender?.toLowerCase() == 'non_binary') {
      topics.addAll(['new_hangouts_bu_nonbinary', 'new_hangouts_all_genders']);
    } else {
      // Users without specified gender or prefer not to say only get all-gender posts
      topics.add('new_hangouts_all_genders');
    }

    if (kDebugMode) {
      print('Subscribing to topics: ${topics.join(", ")}');
    }

    // Subscribe to all appropriate topics using FCM
    for (final topic in topics) {
      try {
        await _firebaseMessaging.subscribeToTopic(topic);
        if (kDebugMode) {
          print('Successfully subscribed to topic: $topic');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error subscribing to topic $topic: $e');
        }
      }
    }

    // Update all subscribed topics in Firestore at once
    await _updateSubscribedTopicsInFirestore(topics);

    if (kDebugMode) {
      print('Completed subscribing to ${topics.length} hangout topics');
    }
  }

  // Method to subscribe to gender-specific topic only (for preferences completion)
  Future<void> subscribeToGenderSpecificTopic(String? gender) async {
    if (gender == null) {
      if (kDebugMode) {
        print(
          'No gender provided, skipping gender-specific topic subscription',
        );
      }
      return;
    }

    String? topicToSubscribe;
    if (gender.toLowerCase() == 'man') {
      topicToSubscribe = 'new_hangouts_bu_men';
    } else if (gender.toLowerCase() == 'woman') {
      topicToSubscribe = 'new_hangouts_bu_women';
    } else if (gender.toLowerCase() == 'non_binary') {
      topicToSubscribe = 'new_hangouts_bu_nonbinary';
    }

    if (topicToSubscribe != null) {
      if (kDebugMode) {
        print(
          'Subscribing to gender-specific topic: $topicToSubscribe for gender: $gender',
        );
      }
      await subscribeToTopic(topicToSubscribe);
    } else {
      if (kDebugMode) {
        print(
          'Unknown gender value: $gender, no gender-specific topic subscription',
        );
      }
    }
  }

  // Method to update subscribed topics in user's Firestore document
  Future<void> _updateSubscribedTopicsInFirestore(List<String> topics) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'subscribedTopics': topics,
          'lastSubscriptionUpdate': FieldValue.serverTimestamp(),
        });

        if (kDebugMode) {
          print('Updated subscribed topics in Firestore for user: ${user.uid}');
          print('Topics: ${topics.join(", ")}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating subscribed topics in Firestore: $e');
      }
    }
  }

  // Method to get current subscribed topics from Firestore
  Future<List<String>> _getSubscribedTopicsFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          return List<String>.from(data['subscribedTopics'] ?? []);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting subscribed topics from Firestore: $e');
      }
    }
    return [];
  }

  // Initialize message handlers for foreground and background notifications
  void initializeMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle notification taps when app was closed/background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    
    // Handle initial message if app was opened from notification
    _handleInitialMessage();
  }

  // Handle messages when app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Received foreground message: ${message.messageId}');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');
    }

    final notificationType = message.data['type'] as String?;
    final authorId = message.data['author_id'] as String?;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // Don't show notification if current user is the author (for new hangout notifications)
    if (notificationType == 'new_hangout' &&
        authorId != null &&
        currentUserId != null &&
        authorId == currentUserId) {
      if (kDebugMode) {
        print('🚫 Blocking notification - user is the author of this hangout');
      }
      return;
    }

    // Don't show foreground notifications for chat messages
    // (chat screen updates in real-time via Firestore listeners)
    if (notificationType == 'chat_message') {
      if (kDebugMode) {
        print('🚫 Suppressing foreground notification for chat message (real-time UI handles this)');
      }
      return;
    }

    // Show in-app notification for other types (hangout joins/leaves, new hangouts, etc.)
    if (message.notification != null) {
      _showInAppNotification(message);
    }
  }

  // Handle notification tap navigation
  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      print('Notification tapped: ${message.messageId}');
      print('Data: ${message.data}');
    }

    _navigateFromNotification(message.data);
  }

  // Handle initial message if app was opened from terminated state
  Future<void> _handleInitialMessage() async {
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        print('App opened from notification: ${initialMessage.messageId}');
      }
      _navigateFromNotification(initialMessage.data);
    }
  }

  // Show in-app notification (customize based on your UI)
  void _showInAppNotification(RemoteMessage message) {
    // This is a basic implementation - you might want to use a more sophisticated approach
    // like flutter_local_notifications or your own custom overlay
    
    final context = NavigationService.navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.notification?.title != null)
                Text(
                  message.notification!.title!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              if (message.notification?.body != null)
                Text(message.notification!.body!),
            ],
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => _navigateFromNotification(message.data),
          ),
        ),
      );
    }
  }

  // Navigate based on notification data
  void _navigateFromNotification(Map<String, dynamic> data) {
    final notificationType = data['type'] as String?;
    final hangoutId = data['hangoutId'] as String? ?? data['hangout_id'] as String?;
    final postId = data['postId'] as String?;

    if (kDebugMode) {
      print('🎯 Navigating from notification: type=$notificationType, hangoutId=$hangoutId, postId=$postId');
      print('🎯 All notification data keys: ${data.keys.toList()}');
      print('🎯 All notification data: $data');
      print('🎯 Navigation context available: ${NavigationService.isNavigationAvailable}');
    }

    // Ensure navigation context is available before attempting navigation
    if (!NavigationService.isNavigationAvailable) {
      if (kDebugMode) {
        print('⚠️ Navigation context not available yet, delaying navigation...');
      }
      // Wait a short moment for context to become available
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateFromNotification(data);
      });
      return;
    }

    if (notificationType == 'new_hangout' && hangoutId != null) {
      // Navigate to hangout invitation screen for new hangout notifications
      if (kDebugMode) {
        print('🎯 Navigating to hangout invitation: $hangoutId');
      }
      NavigationService.goToPath('/hangout/$hangoutId?from=notification');
    } else if ((notificationType == 'hangout_join' || notificationType == 'hangout_leave' || notificationType == 'hangout_update') && hangoutId != null) {
      // Navigate to hangout screen (group members) for join/leave/update notifications
      if (kDebugMode) {
        print('🎯 Navigating to hangout screen: $hangoutId (type: $notificationType)');
      }
      NavigationService.goToPath('/group-members/$hangoutId?from=notification');
    } else if (notificationType == 'chat_message' && postId != null) {
      // Navigate to chat screen for chat message notifications
      if (kDebugMode) {
        print('🎯 Navigating to chat screen: $postId');
      }

      // Build stack: Feed -> Chat (so back button works naturally)
      final context = NavigationService.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        context.go('/feed?tab=hangouts');
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) {
            context.push('/post-chat/$postId');
          }
        });
      }
    }
    // Add more notification types as needed
  }

  // Send notification when someone joins a hangout
  Future<void> notifyHangoutOwnerOfJoin({
    required String hangoutId,
    required String hangoutTitle,
    required String ownerId,
    required String joinerName,
    required String joinerId,
  }) async {
    try {
      if (kDebugMode) {
        print('Sending join notification for hangout: $hangoutId');
      }

      final callable = _functions.httpsCallable('sendJoinNotification');
      await callable.call({
        'hangoutId': hangoutId,
        'hangoutTitle': hangoutTitle,
        'ownerId': ownerId,
        'joinerName': joinerName,
        'joinerId': joinerId,
      });

      if (kDebugMode) {
        print('Join notification sent successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending join notification: $e');
      }
      // Don't throw error - notification failure shouldn't block join operation
    }
  }

  // Send notification when someone leaves a hangout
  Future<void> notifyHangoutOwnerOfLeave({
    required String hangoutId,
    required String hangoutTitle,
    required String ownerId,
    required String leaverName,
    required String leaverId,
  }) async {
    try {
      if (kDebugMode) {
        print('Sending leave notification for hangout: $hangoutId');
      }

      final callable = _functions.httpsCallable('sendLeaveNotification');
      await callable.call({
        'hangoutId': hangoutId,
        'hangoutTitle': hangoutTitle,
        'ownerId': ownerId,
        'leaverName': leaverName,
        'leaverId': leaverId,
      });

      if (kDebugMode) {
        print('Leave notification sent successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending leave notification: $e');
      }
      // Don't throw error - notification failure shouldn't block leave operation
    }
  }

  // Send notification when hangout is updated (title, description, time, or location)
  Future<void> notifyHangoutUpdated({
    required String hangoutId,
    required String hangoutTitle,
    required String ownerId,
    required List<String> participantIds,
    required List<String> changes,
    String? oldTitle,
    String? oldDescription,
    DateTime? oldTime,
    String? oldLocation,
    String? newTitle,
    String? newDescription,
    DateTime? newTime,
    String? newLocation,
  }) async {
    try {
      if (kDebugMode) {
        print('Sending hangout update notification for hangout: $hangoutId');
        print('Changes: ${changes.join(", ")}');
      }

      final callable = _functions.httpsCallable('sendHangoutUpdateNotification');
      await callable.call({
        'hangoutId': hangoutId,
        'hangoutTitle': hangoutTitle,
        'ownerId': ownerId,
        'participantIds': participantIds,
        'changes': changes,
        'oldTitle': oldTitle,
        'oldDescription': oldDescription,
        'oldTime': oldTime?.toIso8601String(),
        'oldLocation': oldLocation,
        'newTitle': newTitle,
        'newDescription': newDescription,
        'newTime': newTime?.toIso8601String(),
        'newLocation': newLocation,
      });

      if (kDebugMode) {
        print('Hangout update notification sent successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending hangout update notification: $e');
      }
      // Don't throw error - notification failure shouldn't block update operation
    }
  }

  // Toggle chat notifications for a specific hangout
  Future<void> toggleHangoutChatNotifications(
    String hangoutId,
    bool enabled,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('No user logged in - cannot toggle chat notifications');
        }
        return;
      }

      if (kDebugMode) {
        print('Toggling chat notifications for hangout $hangoutId: $enabled');
      }

      // Update the user's notification preferences in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'hangoutChatNotifications.$hangoutId': enabled,
      });

      if (kDebugMode) {
        print('Successfully updated chat notification preference for hangout $hangoutId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling chat notifications: $e');
      }
      rethrow;
    }
  }

  // Get chat notification preference for a specific hangout
  Future<bool> getHangoutChatNotificationPreference(String hangoutId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('No user logged in - returning default notification preference');
        }
        return true; // Default to enabled
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        return true; // Default to enabled
      }

      final data = doc.data();
      if (data == null) {
        return true; // Default to enabled
      }

      final notificationPrefs = data['hangoutChatNotifications'] as Map<String, dynamic>?;
      if (notificationPrefs == null) {
        return true; // Default to enabled
      }

      // Return the preference for this specific hangout, default to true if not set
      return notificationPrefs[hangoutId] as bool? ?? true;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting chat notification preference: $e');
      }
      return true; // Default to enabled on error
    }
  }

  // You can add other methods here for handling incoming messages, etc.
}
