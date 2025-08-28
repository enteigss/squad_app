import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  static const String hangoutScheme = 'linkupbu';
  
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  
  // Initialize deep link handling
  Future<void> initialize(BuildContext context) async {
    try {
      // Handle app launch from deep link (when app is closed)
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        await _handleDeepLink(context, initialLink);
      }

      // Handle deep links when app is already running
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) => _handleDeepLink(context, uri),
        onError: (error) {
          debugPrint('Deep link error: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to initialize deep links: $e');
    }
  }

  // Handle incoming deep links
  Future<void> _handleDeepLink(BuildContext context, Uri uri) async {
    try {
      debugPrint('Received deep link: $uri');
      
      if (uri.scheme != hangoutScheme) {
        debugPrint('Unknown scheme: ${uri.scheme}');
        return;
      }

      // Parse the path to determine the action
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.isNotEmpty && pathSegments[0] == 'hangout') {
        await _handleHangoutInvite(context, uri, pathSegments);
      } else {
        debugPrint('Unknown deep link path: ${uri.path}');
      }
    } catch (e) {
      debugPrint('Error handling deep link: $e');
    }
  }

  // Handle hangout invite deep links
  Future<void> _handleHangoutInvite(
    BuildContext context, 
    Uri uri, 
    List<String> pathSegments
  ) async {
    try {
      if (pathSegments.length < 2) {
        debugPrint('Invalid hangout deep link: missing hangout ID');
        return;
      }

      final hangoutId = pathSegments[1];
      final inviterId = uri.queryParameters['inviter'];
      
      debugPrint('Navigating to hangout: $hangoutId, inviter: $inviterId');

      // Wait a bit to ensure the app is fully initialized
      await Future.delayed(const Duration(milliseconds: 500));

      if (context.mounted) {
        // Navigate to the hangout detail page
        // Assuming you have a hangout detail route
        context.go('/hangout/$hangoutId');
        
        // Show invite notification
        _showInviteNotification(context, hangoutId, inviterId);
      }
    } catch (e) {
      debugPrint('Error handling hangout invite: $e');
    }
  }

  // Show notification that user was invited
  void _showInviteNotification(
    BuildContext context, 
    String hangoutId, 
    String? inviterId
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('🎉 You\'ve been invited to join this hangout!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'JOIN',
          textColor: Colors.white,
          onPressed: () {
            // Handle join action - this could trigger joining the hangout
            _handleJoinHangout(context, hangoutId);
          },
        ),
      ),
    );
  }

  // Handle joining hangout from invite
  void _handleJoinHangout(BuildContext context, String hangoutId) {
    // TODO: Implement auto-join logic here
    // This could automatically join the user to the hangout
    // or show a join confirmation dialog
    debugPrint('User wants to join hangout: $hangoutId');
  }

  // Create deep link URL for hangout invite
  static String createHangoutInviteLink({
    required String hangoutId,
    String? inviterId,
  }) {
    final uri = Uri(
      scheme: hangoutScheme,
      path: '/hangout/$hangoutId',
      queryParameters: inviterId != null ? {'inviter': inviterId} : null,
    );
    return uri.toString();
  }

  // Dispose resources
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}