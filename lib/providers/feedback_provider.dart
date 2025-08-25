import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meetup_feedback.dart';
import '../services/feedback_service.dart';

class FeedbackProvider with ChangeNotifier {
  final FeedbackService _feedbackService = FeedbackService();
  
  List<PendingFeedbackPrompt> _pendingPrompts = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<PendingFeedbackPrompt>>? _promptsSubscription;
  
  // Getters
  List<PendingFeedbackPrompt> get pendingPrompts => _pendingPrompts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasPendingPrompts => _pendingPrompts.isNotEmpty;
  PendingFeedbackPrompt? get nextPrompt => _pendingPrompts.isNotEmpty ? _pendingPrompts.first : null;

  // Initialize feedback prompts for a specific user
  Future<void> initialize(String userId) async {
    debugPrint('FeedbackProvider: Initializing for user $userId');
    _setLoading(true);
    _clearError();
    
    try {
      // Check Firestore connection state
      await _checkFirestoreConnection();
      
      // Cancel any existing subscription
      await _promptsSubscription?.cancel();
      
      // Subscribe to pending prompts
      _promptsSubscription = _feedbackService.getPendingFeedbackPrompts(userId).listen(
        (prompts) {
          final notifyTime = DateTime.now();
          debugPrint('FeedbackProvider: Received ${prompts.length} pending prompts at: ${notifyTime.toIso8601String()}');
          _pendingPrompts = prompts;
          notifyListeners();
          debugPrint('FeedbackProvider: notifyListeners() called at: ${DateTime.now().toIso8601String()}');
        },
        onError: (error) {
          debugPrint('FeedbackProvider: Error loading prompts: $error');
          
          // Check if error is related to missing index
          final errorMessage = error.toString().toLowerCase();
          if (errorMessage.contains('index') || errorMessage.contains('composite')) {
            debugPrint('FeedbackProvider: INDEX ERROR DETECTED - Compound index may be missing!');
            debugPrint('FeedbackProvider: Required index: Collection: pending_feedback_prompts, Fields: userId (Ascending), isShown (Ascending), createdAt (Descending)');
          }
          
          _setError('Failed to load feedback prompts: $error');
        },
      );
    } catch (e) {
      debugPrint('FeedbackProvider: Initialize error: $e');
      _setError('Failed to initialize feedback prompts: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Mark a prompt as shown
  Future<void> markPromptAsShown(String promptId) async {
    try {
      await _feedbackService.markPromptAsShown(promptId);
      // The stream will automatically update the prompts list
    } catch (e) {
      _setError('Failed to mark prompt as shown: $e');
    }
  }

  // Submit feedback for a prompt
  Future<bool> submitFeedback({
    required String hangoutId,
    required String userId,
    required String hangoutTitle,
    required bool didMeetup,
    String? additionalFeedback,
  }) async {
    try {
      await _feedbackService.submitFeedback(
        hangoutId: hangoutId,
        userId: userId,
        hangoutTitle: hangoutTitle,
        didMeetup: didMeetup,
        additionalFeedback: additionalFeedback,
      );
      return true;
    } catch (e) {
      _setError('Failed to submit feedback: $e');
      return false;
    }
  }

  // Clean up old prompts
  Future<void> cleanupOldPrompts() async {
    try {
      await _feedbackService.cleanupOldPendingPrompts();
    } catch (e) {
      debugPrint('Failed to cleanup old prompts: $e');
      // Don't set error for cleanup failures
    }
  }

  // Get feedback statistics
  Future<Map<String, dynamic>> getFeedbackStats() async {
    try {
      return await _feedbackService.getFeedbackStats();
    } catch (e) {
      _setError('Failed to get feedback stats: $e');
      return {
        'totalFeedbacks': 0,
        'successfulMeetups': 0,
        'unsuccessfulMeetups': 0,
        'successRate': 0.0,
      };
    }
  }

  // Private helper methods
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
  
  // Check Firestore connection and settings
  Future<void> _checkFirestoreConnection() async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Log current Firestore settings
      debugPrint('FeedbackProvider: Checking Firestore connection...');
      debugPrint('FeedbackProvider: App: ${firestore.app.name}');
      
      // Try a simple operation to test connectivity
      final connectionTestStart = DateTime.now();
      await firestore.collection('pending_feedback_prompts').limit(1).get();
      final connectionTestDuration = DateTime.now().difference(connectionTestStart).inMilliseconds;
      
      debugPrint('FeedbackProvider: Firestore connection test completed in ${connectionTestDuration}ms');
      
      // Check if we're in offline mode
      try {
        await firestore.enableNetwork();
        debugPrint('FeedbackProvider: Firestore network enabled');
      } catch (e) {
        debugPrint('FeedbackProvider: Firestore network state: $e');
      }
      
    } catch (e) {
      debugPrint('FeedbackProvider: Firestore connection check failed: $e');
    }
  }

  @override
  void dispose() {
    _promptsSubscription?.cancel();
    super.dispose();
  }
}