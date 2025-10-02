import 'environment.dart';

class AppConfig {
  static const String appName = 'LinkUp BU';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';

  static bool get isDevelopment => EnvironmentConfig.isDev;
  static bool get isProduction => EnvironmentConfig.isProd;

  static const String firebaseProjectId = 'your-firebase-project-id';
  static const String firebaseApiKey = 'your-firebase-api-key';
  static const String firebaseAuthDomain =
      'your-firebase-project-id.firebaseapp.com';
  static const String firebaseStorageBucket =
      'your-firebase-project-id.appspot.com';
  static const String firebaseMessagingSenderId = 'your-messaging-sender-id';
  static const String firebaseAppId = 'your-firebase-app-id';

  static const String androidPackageName = 'com.example.squad_app';
  static const String iosPackageName = 'com.example.squadApp';

  static const String privacyPolicyUrl = 'https://example.com/privacy';
  static const String termsOfServiceUrl = 'https://example.com/terms';
  static const String supportUrl = 'https://example.com/support';
  static const String feedbackUrl = 'https://example.com/feedback';

  static const String supportEmail = 'support@example.com';
  static const String feedbackEmail = 'feedback@example.com';

  static const Map<String, String> socialLinks = {
    'website': 'https://example.com',
    'twitter': 'https://twitter.com/linkupbu',
    'instagram': 'https://instagram.com/linkupbu',
    'facebook': 'https://facebook.com/linkupbu',
  };

  static const int cacheExpirationHours = 24;
  static const int maxRetryAttempts = 3;
  static const int requestTimeoutSeconds = 30;

  static const bool enableAnalytics = true;
  static const bool enableCrashlytics = true;
  static const bool enablePerformanceMonitoring = true;
  static const bool enableRemoteConfig = true;

  static bool get enableLogging => isDevelopment;
  static bool get enableDebugFeatures => isDevelopment;

  static const int maxImageUploadSizeMB = 10;
  static const int maxFileUploadSizeMB = 50;
  static const int maxGroupMembers = 100;
  static const int maxMessageLength = 1000;

  static const List<String> supportedLanguages = [
    'en',
    'es',
    'fr',
    'de',
    'it',
    'pt',
    'ru',
    'zh',
    'ja',
    'ko',
  ];

  static const String defaultLanguage = 'en';
  static const String defaultTheme = 'system';

  static Map<String, String> get apiEndpoints => {
    'base': isDevelopment
        ? 'https://api-dev.example.com'
        : 'https://api.example.com',
    'auth': '/auth',
    'users': '/users',
    'groups': '/groups',
    'messages': '/messages',
    'notifications': '/notifications',
  };

  static const Map<String, String> firebaseRegions = {
    'functions': 'us-central1',
    'firestore': 'us-central1',
    'storage': 'us-central1',
  };

  static const Map<String, dynamic> featureFlags = {
    'enableVoiceMessages': false,
    'enableVideoMessages': false,
    'enableGroupCalls': false,
    'enableFileSharing': true,
    'enableMessageReactions': true,
    'enableMessageThreads': false,
    'enableUserStatus': true,
    'enablePushNotifications': true,
    'enableInAppNotifications': true,
    'enableDarkMode': true,
    'enableBiometricAuth': false,
    'enableLocationSharing': false,
    'enableMessageEncryption': false,
  };

  static const Map<String, int> rateLimits = {
    'messagesPerMinute': 60,
    'groupCreationPerHour': 5,
    'userSearchPerMinute': 30,
    'fileUploadsPerHour': 20,
  };

  static const Map<String, String> defaultAvatars = {
    'user': 'assets/images/default_user_avatar.png',
    'group': 'assets/images/default_group_avatar.png',
  };

  static const Map<String, String> errorImages = {
    'network': 'assets/images/no_network.png',
    'notFound': 'assets/images/not_found.png',
    'error': 'assets/images/error.png',
  };

  static bool isFeaturedEnabled(String feature) {
    return featureFlags[feature] == true;
  }

  static String get apiBaseUrl => apiEndpoints['base']!;

  static String getApiEndpoint(String endpoint) {
    return apiBaseUrl + (apiEndpoints[endpoint] ?? '');
  }

  static bool isFeatureFlagEnabled(String feature) {
    return featureFlags[feature] == true;
  }

  static int getRateLimit(String action) {
    return rateLimits[action] ?? 0;
  }

  static String getDefaultAvatar(String type) {
    return defaultAvatars[type] ?? defaultAvatars['user']!;
  }

  static String getErrorImage(String type) {
    return errorImages[type] ?? errorImages['error']!;
  }
}
