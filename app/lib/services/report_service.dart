import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/report_model.dart';

class ReportService {
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  ReportService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<void> submitReport({
    required String contentType,
    required String contentId,
    required String contentTitle,
    required String authorId,
    required Map<String, dynamic> contentSnippet,
    required ReportReason reason,
    required String reporterUid,
    required String reporterDisplayName,
  }) async {
    try {
      debugPrint('🚩 ReportService: Starting report submission');
      debugPrint('🚩 ReportService: Content Type: $contentType');
      debugPrint('🚩 ReportService: Content ID: $contentId');
      debugPrint('🚩 ReportService: Reason: ${reason.displayName}');

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('🚩 ReportService: User authenticated: ${user.uid}');

      // Prepare data for callable function
      final reportData = {
        'status': 'pending',
        'timestamp': DateTime.now().toIso8601String(),
        'reason': reason.value,
        'reporterInfo': {
          'uid': reporterUid,
          'displayName': reporterDisplayName,
        },
        'reportedContentInfo': {
          'contentType': contentType,
          'contentId': contentId,
          'authorId': authorId,
          'contentSnippet': contentSnippet,
        },
      };

      debugPrint('🚩 ReportService: Calling submitReport cloud function');

      // Call the cloud function
      final callable = _functions.httpsCallable('submitReport');
      final result = await callable.call(reportData);

      debugPrint('🚩 ReportService: Cloud function response received');
      debugPrint('🚩 ReportService: Result data: ${result.data}');

      final responseData = result.data as Map<String, dynamic>;
      
      if (responseData['success'] == true) {
        debugPrint('🚩 ReportService: Report submitted successfully');
        debugPrint('🚩 ReportService: Report ID: ${responseData['reportId']}');
      } else {
        final errorMessage = responseData['message'] ?? 'Failed to submit report';
        debugPrint('🚩 ReportService: Report submission failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('🚩 ReportService: Exception during report submission: $e');
      debugPrint('🚩 ReportService: Exception type: ${e.runtimeType}');
      
      // Handle specific Firebase Functions errors
      if (e is FirebaseFunctionsException) {
        debugPrint('🚩 ReportService: Firebase Functions error: ${e.code} - ${e.message}');
        throw Exception(e.message ?? 'Cloud function error');
      }
      
      if (e.toString().contains('not authenticated')) {
        throw Exception('Authentication failed. Please sign in again.');
      } else {
        throw Exception('Failed to submit report: $e');
      }
    }
  }

  // Helper method to create content snippet for hangout reports
  static Map<String, dynamic> createHangoutContentSnippet({
    required String title,
    required String description,
    String? location,
    int? participantCount,
    DateTime? scheduledTime,
  }) {
    return {
      'hangout_title': title,
      'hangout_description': description,
      if (location != null) 'location': location,
      if (participantCount != null) 'participant_count': participantCount,
      if (scheduledTime != null) 
        'scheduled_time': scheduledTime.toIso8601String(),
    };
  }

  // Helper method to create content snippet for user reports
  static Map<String, dynamic> createUserContentSnippet({
    required String displayName,
    String? bio,
    String? location,
    List<String>? interests,
  }) {
    return {
      'user_display_name': displayName,
      if (bio != null) 'bio': bio,
      if (location != null) 'location': location,
      if (interests != null) 'interests': interests,
    };
  }
}