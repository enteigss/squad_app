import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
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

  // You can add other methods here for handling incoming messages, etc.
}