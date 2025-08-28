import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

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
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      if (kDebugMode) {
        print('FCM Token: $token');
      }
      // IMPORTANT: Send this token to your backend server to store against the user's profile.
      // This is how you will target this specific device for push notifications.
      // Example: await myApi.saveUserFcmToken(token);
    }
  }

  // You can add other methods here for handling incoming messages, etc.
}