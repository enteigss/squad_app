class AppConstants {
  static const String appName = 'LinkUp BU';
  static const String appVersion = '1.0.0';
  
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);
  
  static const double borderRadius = 8.0;
  static const double largeBorderRadius = 16.0;
  static const double smallBorderRadius = 4.0;
  
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;
  
  static const double marginXS = 4.0;
  static const double marginS = 8.0;
  static const double marginM = 16.0;
  static const double marginL = 24.0;
  static const double marginXL = 32.0;
  
  static const double iconSizeS = 16.0;
  static const double iconSizeM = 24.0;
  static const double iconSizeL = 32.0;
  static const double iconSizeXL = 48.0;
  
  static const double avatarSizeS = 32.0;
  static const double avatarSizeM = 48.0;
  static const double avatarSizeL = 64.0;
  static const double avatarSizeXL = 96.0;
  
  static const double buttonHeightS = 32.0;
  static const double buttonHeightM = 48.0;
  static const double buttonHeightL = 56.0;
  
  static const int maxUsernameLength = 30;
  static const int minUsernameLength = 3;
  static const int maxDisplayNameLength = 50;
  static const int maxBioLength = 150;
  static const int maxGroupNameLength = 50;
  static const int maxGroupDescriptionLength = 200;
  static const int maxMessageLength = 1000;
  
  static const int passwordMinLength = 6;
  static const int passwordMaxLength = 128;
  
  static const List<String> supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  ];
  
  static const List<String> supportedFileFormats = [
    'pdf',
    'doc',
    'docx',
    'txt',
    'zip',
    'rar',
  ];
  
  static const int maxFileSize = 50 * 1024 * 1024;
  static const int maxImageSize = 10 * 1024 * 1024;
  
  static const String termsOfServiceUrl = 'https://example.com/terms';
  static const String privacyPolicyUrl = 'https://example.com/privacy';
  static const String supportEmailUrl = 'mailto:support@example.com';
  
  static const String defaultProfileImageUrl = '';
  static const String defaultGroupImageUrl = '';
  
  static const String dateFormat = 'MMM dd, yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'MMM dd, yyyy HH:mm';
}

class FirebaseConstants {
  static const String usersCollection = 'users';
  static const String groupsCollection = 'groups';
  static const String messagesCollection = 'messages';
  
  static const String profileImagesPath = 'profile_images';
  static const String groupImagesPath = 'group_images';
  static const String messageImagesPath = 'message_images';
  static const String messageFilesPath = 'message_files';
}

class RouteConstants {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String profileSetup = '/profile-setup';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String group = '/group';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String createGroup = '/create-group';
  static const String addMembers = '/add-members';
  static const String groupSettings = '/group-settings';
}

class ErrorMessages {
  static const String networkError = 'Network error. Please check your connection.';
  static const String unknownError = 'An unknown error occurred. Please try again.';
  static const String invalidEmail = 'Please enter a valid email address.';
  static const String invalidPassword = 'Password must be at least 6 characters long.';
  static const String invalidUsername = 'Username must be 3-30 characters long and contain only letters, numbers, and underscores.';
  static const String usernameRequired = 'Username is required.';
  static const String emailRequired = 'Email is required.';
  static const String passwordRequired = 'Password is required.';
  static const String displayNameRequired = 'Display name is required.';
  static const String groupNameRequired = 'Group name is required.';
  static const String messageRequired = 'Message cannot be empty.';
  static const String fileTooLarge = 'File size exceeds the maximum limit.';
  static const String unsupportedFileFormat = 'File format is not supported.';
  static const String cameraPermissionDenied = 'Camera permission is required to take photos.';
  static const String storagePermissionDenied = 'Storage permission is required to access files.';
}

class SuccessMessages {
  static const String accountCreated = 'Account created successfully!';
  static const String loginSuccessful = 'Login successful!';
  static const String profileUpdated = 'Profile updated successfully!';
  static const String groupCreated = 'Group created successfully!';
  static const String messageSent = 'Message sent!';
  static const String passwordResetSent = 'Password reset email sent!';
  static const String userAddedToGroup = 'User added to group successfully!';
  static const String userRemovedFromGroup = 'User removed from group successfully!';
}