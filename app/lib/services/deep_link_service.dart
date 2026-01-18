import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'navigation_service.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  static const String hangoutScheme = 'com.jordan.linkupbu';

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
      debugPrint('URI scheme: ${uri.scheme}');
      debugPrint('URI host: ${uri.host}');
      debugPrint('URI path: ${uri.path}');
      debugPrint('URI pathSegments: ${uri.pathSegments}');
      debugPrint('URI pathSegments length: ${uri.pathSegments.length}');

      if (uri.scheme != hangoutScheme) {
        debugPrint('Unknown scheme: ${uri.scheme}');
        return;
      }

      // Check if hangout is in the host (due to custom scheme parsing)
      if (uri.host == 'hangout' && uri.pathSegments.isNotEmpty) {
        final hangoutId = uri.pathSegments[0];
        final inviterId = uri.queryParameters['inviter'];
        debugPrint(
          'Detected hangout as host, navigating to hangout: $hangoutId, inviter: $inviterId',
        );

        // Wait a bit to ensure the app is fully initialized
        await Future.delayed(const Duration(milliseconds: 500));

        // Use global navigation service instead of context.go()
        NavigationService.goToHangout(hangoutId);

        // Show notification using available context or global context
        final notificationContext = NavigationService.currentContext ?? context;
        if (notificationContext.mounted) {
          _showInviteNotification(notificationContext, hangoutId, inviterId);
        }
        return;
      }

      // Fallback to original path-based parsing
      final pathSegments = uri.pathSegments;
      debugPrint('Path segments: ${pathSegments}');

      if (pathSegments.isNotEmpty && pathSegments[0] == 'hangout') {
        await _handleHangoutInvite(context, uri, pathSegments);
      } else {
        debugPrint(
          'Unknown deep link structure - Host: ${uri.host}, Path: ${uri.path}',
        );
      }
    } catch (e) {
      debugPrint('Error handling deep link: $e');
    }
  }

  // Handle hangout invite deep links
  Future<void> _handleHangoutInvite(
    BuildContext context,
    Uri uri,
    List<String> pathSegments,
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

      // Use global navigation service instead of context.go()
      NavigationService.goToHangout(hangoutId);

      // Show notification using available context or global context
      final notificationContext = NavigationService.currentContext ?? context;
      if (notificationContext.mounted) {
        _showInviteNotification(notificationContext, hangoutId, inviterId);
      }
    } catch (e) {
      debugPrint('Error handling hangout invite: $e');
    }
  }

  // Show notification that user was invited
  void _showInviteNotification(
    BuildContext context,
    String hangoutId,
    String? inviterId,
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
