import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  late FirebaseAnalytics _analytics;
  late FirebaseAnalyticsObserver _observer;
  
  bool _isFirstHangoutView = true;
  bool _isFirstHangoutJoin = true;

  FirebaseAnalytics get analytics => _analytics;
  FirebaseAnalyticsObserver get observer => _observer;

  void initialize() {
    _analytics = FirebaseAnalytics.instance;
    _observer = FirebaseAnalyticsObserver(analytics: _analytics);
    
    if (kDebugMode) {
      print('Firebase Analytics initialized');
    }
  }

  // Set user properties for better segmentation
  Future<void> setUserId(String userId) async {
    await _analytics.setUserId(id: userId);
  }

  Future<void> setUserProperties({
    String? gender,
    String? ageRange,
    String? signupDate,
    String? location,
  }) async {
    if (gender != null) {
      await _analytics.setUserProperty(name: 'gender', value: gender);
    }
    if (ageRange != null) {
      await _analytics.setUserProperty(name: 'age_range', value: ageRange);
    }
    if (signupDate != null) {
      await _analytics.setUserProperty(name: 'signup_date', value: signupDate);
    }
    if (location != null) {
      await _analytics.setUserProperty(name: 'location', value: location);
    }
  }

  // User journey tracking
  Future<void> trackUserSignup({
    required String method,
    String? userId,
  }) async {
    await _analytics.logSignUp(signUpMethod: method);
    
    await _analytics.logEvent(
      name: 'user_signup_completed',
      parameters: {
        'signup_method': method,
        'timestamp': DateTime.now().toIso8601String(),
        if (userId != null) 'user_id': userId,
      },
    );
    
    if (kDebugMode) {
      print('Analytics: User signup tracked - method: $method');
    }
  }

  Future<void> trackLogin({
    required String method,
    String? userId,
  }) async {
    await _analytics.logLogin(loginMethod: method);
    
    if (kDebugMode) {
      print('Analytics: Login tracked - method: $method');
    }
  }

  // Hangout creation tracking
  Future<void> trackHangoutCreated({
    required String hangoutId,
    required String title,
    required String authorId,
    required DateTime scheduledTime,
    required String genderPreference,
    int? maxParticipants,
    bool hasDescription = false,
  }) async {
    final now = DateTime.now();
    final isNow = scheduledTime.difference(now).inMinutes.abs() < 1;
    final scheduledType = isNow ? 'now' : 'scheduled';
    
    await _analytics.logEvent(
      name: 'hangout_created',
      parameters: {
        'hangout_id': hangoutId,
        'title_length': title.length,
        'author_id': authorId,
        'scheduled_type': scheduledType,
        'gender_preference': genderPreference,
        'max_participants': maxParticipants ?? 0,
        'has_description': hasDescription ? 1 : 0,
        'time_to_event_hours': isNow ? 0 : scheduledTime.difference(now).inHours,
        'creation_timestamp': now.toIso8601String(),
      },
    );
    
    if (kDebugMode) {
      print('Analytics: Hangout created - id: $hangoutId, type: $scheduledType');
    }
  }

  // Hangout viewing tracking
  Future<void> trackHangoutViewed({
    required String hangoutId,
    required String hangoutTitle,
    required String viewerId,
    required String authorId,
    required bool canJoin,
    required bool isParticipant,
    required int currentParticipants,
    required int maxParticipants,
  }) async {
    bool isFirstView = false;
    
    // Track first hangout view for conversion funnel
    if (_isFirstHangoutView) {
      _isFirstHangoutView = false;
      isFirstView = true;
      
      await _analytics.logEvent(
        name: 'first_hangout_view',
        parameters: {
          'hangout_id': hangoutId,
          'viewer_id': viewerId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
    
    // Track all hangout views for engagement analysis
    await _analytics.logEvent(
      name: 'hangout_viewed',
      parameters: {
        'hangout_id': hangoutId,
        'title_length': hangoutTitle.length,
        'viewer_id': viewerId,
        'author_id': authorId,
        'can_join': canJoin ? 1 : 0,
        'is_participant': isParticipant ? 1 : 0,
        'is_first_view': isFirstView ? 1 : 0,
        'current_participants': currentParticipants,
        'max_participants': maxParticipants,
        'fill_rate': currentParticipants / maxParticipants,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    if (kDebugMode) {
      print('Analytics: Hangout viewed - id: $hangoutId, first_view: $isFirstView');
    }
  }

  // Hangout joining tracking
  Future<void> trackHangoutJoined({
    required String hangoutId,
    required String hangoutTitle,
    required String userId,
    required String authorId,
    required int participantsAfterJoin,
    required int maxParticipants,
    required bool isSuccessful,
    String? joinSource, // 'detail_screen', 'feed_screen', 'deep_link', etc.
  }) async {
    bool isFirstJoin = false;
    
    if (isSuccessful) {
      // Track first hangout join for conversion funnel
      if (_isFirstHangoutJoin) {
        _isFirstHangoutJoin = false;
        isFirstJoin = true;
        
        await _analytics.logEvent(
          name: 'first_hangout_join',
          parameters: {
            'hangout_id': hangoutId,
            'user_id': userId,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
      
      // Firebase's built-in join_group event
      await _analytics.logJoinGroup(groupId: hangoutId);
    }
    
    // Track all join attempts for analysis
    await _analytics.logEvent(
      name: 'hangout_join_attempt',
      parameters: {
        'hangout_id': hangoutId,
        'title_length': hangoutTitle.length,
        'user_id': userId,
        'author_id': authorId,
        'is_successful': isSuccessful ? 1 : 0,
        'is_first_join': isFirstJoin ? 1 : 0,
        'join_source': joinSource ?? 'unknown',
        'max_participants': maxParticipants,
        if (isSuccessful) 'participants_after': participantsAfterJoin,
        if (isSuccessful) 'new_fill_rate': participantsAfterJoin / maxParticipants,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    if (kDebugMode) {
      print('Analytics: Hangout join attempt - id: $hangoutId, success: $isSuccessful, first_join: $isFirstJoin');
    }
  }

  // Hangout leaving tracking (if you implement this feature later)
  Future<void> trackHangoutLeft({
    required String hangoutId,
    required String userId,
    required int participantsAfter,
  }) async {
    await _analytics.logEvent(
      name: 'hangout_left',
      parameters: {
        'hangout_id': hangoutId,
        'user_id': userId,
        'participants_after': participantsAfter,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Screen tracking
  Future<void> trackScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass ?? screenName,
    );
    
    if (kDebugMode) {
      print('Analytics: Screen view - $screenName');
    }
  }

  // Custom events for specific features
  Future<void> trackInviteSent({
    required String hangoutId,
    required String method, // 'sms', 'share_link', etc.
    int? recipientCount,
  }) async {
    await _analytics.logEvent(
      name: 'invite_sent',
      parameters: {
        'hangout_id': hangoutId,
        'method': method,
        'recipient_count': recipientCount ?? 1,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> trackFeatureUsage({
    required String featureName,
    Map<String, Object>? additionalParams,
  }) async {
    final params = <String, Object>{
      'feature_name': featureName,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }
    
    await _analytics.logEvent(
      name: 'feature_used',
      parameters: params,
    );
  }

  // Error tracking
  Future<void> trackError({
    required String errorType,
    required String errorMessage,
    String? screen,
    String? userId,
  }) async {
    await _analytics.logEvent(
      name: 'app_error',
      parameters: {
        'error_type': errorType,
        'error_message': errorMessage,
        if (screen != null) 'screen': screen,
        if (userId != null) 'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Meetup feedback tracking
  Future<void> trackMeetupFeedbackSubmitted({
    required String hangoutId,
    required bool didMeetup,
    bool hasAdditionalFeedback = false,
  }) async {
    await _analytics.logEvent(
      name: 'meetup_feedback_submitted',
      parameters: {
        'hangout_id': hangoutId,
        'did_meetup': didMeetup ? 1 : 0,
        'has_additional_feedback': hasAdditionalFeedback ? 1 : 0,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    if (kDebugMode) {
      print('Analytics: Meetup feedback submitted - hangout: $hangoutId, success: $didMeetup');
    }
  }

  // Reset first-time flags (useful for testing or if user logs out and back in)
  void resetFirstTimeFlags() {
    _isFirstHangoutView = true;
    _isFirstHangoutJoin = true;
  }

  // Get current first-time states (useful for debugging)
  Map<String, bool> getFirstTimeStates() {
    return {
      'isFirstHangoutView': _isFirstHangoutView,
      'isFirstHangoutJoin': _isFirstHangoutJoin,
    };
  }
}