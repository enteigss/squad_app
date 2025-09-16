import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherHelper {
  static const String _baseUrl =
      'https://squad-7bc7e.web.app/'; // Replace with your actual Firebase hosting URL

  static const String privacyPolicyUrl = '$_baseUrl/privacy-policy';
  static const String dataDeletionUrl = '$_baseUrl/data-deletion';
  static const String childSafetyUrl = '$_baseUrl/child-safety';

  /// Launch a URL in the external browser
  static Future<bool> launchExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch URL: $url');
        return false;
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      return false;
    }
  }

  /// Launch a URL in an in-app web view
  static Future<bool> launchInApp(String url) async {
    try {
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
      } else {
        debugPrint('Could not launch URL: $url');
        return false;
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      return false;
    }
  }

  /// Launch privacy policy
  static Future<bool> launchPrivacyPolicy() async {
    return await launchExternalUrl(privacyPolicyUrl);
  }

  /// Launch data deletion page
  static Future<bool> launchDataDeletion() async {
    return await launchExternalUrl(dataDeletionUrl);
  }

  /// Launch child safety page
  static Future<bool> launchChildSafety() async {
    return await launchExternalUrl(childSafetyUrl);
  }

  /// Launch email for support
  static Future<bool> launchSupportEmail() async {
    const email = 'support@linkupbu.com'; // Replace with your support email
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'LinkUp BU Support Request'},
    );

    return await launchExternalUrl(uri.toString());
  }
}
