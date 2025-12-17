import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  FirebaseAnalyticsObserver? _observer;
  bool _isInitialized = false;

  FirebaseAnalytics? get analytics => _analytics;
  FirebaseAnalyticsObserver? get observer => _observer;
  bool get isInitialized => _isInitialized;

  /// Check if user has given consent for analytics
  Future<bool> isConsentGiven() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('analytics_consent') ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking analytics consent: $e');
      }
      return false;
    }
  }

  void initialize() {
    _analytics = FirebaseAnalytics.instance;
    _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
    _isInitialized = true;

    // Enable Firebase Analytics data collection
    _analytics!.setAnalyticsCollectionEnabled(true);

    if (kDebugMode) {
      print('Firebase Analytics initialized and data collection enabled');
    }
  }

  void disable() {
    if (_analytics != null) {
      // Disable Firebase Analytics data collection completely
      _analytics!.setAnalyticsCollectionEnabled(false);
      if (kDebugMode) {
        print('Firebase Analytics data collection disabled');
      }
    }

    // Clear the service state
    _analytics = null;
    _observer = null;
    _isInitialized = false;

    if (kDebugMode) {
      print('AnalyticsService disabled');
    }
  }

  // Track hangout creation (metric 1: number of hangouts created)
  Future<void> trackHangoutCreated({
    required String userId,
    required String hangoutId,
  }) async {
    if (!_isInitialized || _analytics == null) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await _analytics!.logEvent(
      name: 'hangout_created',
      parameters: {
        'user_id': userId,
        'hangout_id': hangoutId,
        'timestamp': timestamp,
      },
    );

    if (kDebugMode) {
      print(
        'Analytics: Hangout created - userId: $userId, hangoutId: $hangoutId, timestamp: $timestamp',
      );
    }
  }

  // Track hangout join (metric 4: number of hangout joins)
  Future<void> trackHangoutJoined({
    required String userId,
    required String hangoutId,
  }) async {
    if (!_isInitialized || _analytics == null) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await _analytics!.logEvent(
      name: 'hangout_joined',
      parameters: {
        'user_id': userId,
        'hangout_id': hangoutId,
        'timestamp': timestamp,
      },
    );

    if (kDebugMode) {
      print(
        'Analytics: Hangout joined - userId: $userId, hangoutId: $hangoutId, timestamp: $timestamp',
      );
    }
  }

  // Track meetup success (metric 2: how many meetups happened)
  Future<void> trackMeetupSuccess({
    required bool didMeetup,
    required String hangoutId,
  }) async {
    if (!_isInitialized || _analytics == null) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await _analytics!.logEvent(
      name: 'meetup_feedback',
      parameters: {
        'success': didMeetup ? 1 : 0,
        'hangout_id': hangoutId,
        'timestamp': timestamp,
      },
    );

    if (kDebugMode) {
      print(
        'Analytics: Meetup feedback - success: $didMeetup, hangoutId: $hangoutId, timestamp: $timestamp',
      );
    }
  }

  // Track user sign up
  Future<void> trackUserSignUp({required String userId}) async {
    if (!_isInitialized || _analytics == null) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await _analytics!.logEvent(
      name: 'user_sign_up',
      parameters: {'user_id': userId, 'timestamp': timestamp},
    );

    if (kDebugMode) {
      print('Analytics: User sign up - userId: $userId, timestamp: $timestamp');
    }
  }

  // Active users (metric 3) are automatically tracked by Firebase Analytics
  // No custom implementation needed - Firebase tracks DAU/WAU/MAU automatically
}
