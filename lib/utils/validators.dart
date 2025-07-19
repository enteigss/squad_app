import 'constants.dart';

class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return ErrorMessages.emailRequired;
    }
    
    final RegExp emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return ErrorMessages.invalidEmail;
    }
    
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return ErrorMessages.passwordRequired;
    }
    
    if (value.length < AppConstants.passwordMinLength) {
      return ErrorMessages.invalidPassword;
    }
    
    if (value.length > AppConstants.passwordMaxLength) {
      return 'Password must be less than ${AppConstants.passwordMaxLength} characters long.';
    }
    
    return null;
  }

  static String? validateConfirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }
    
    if (value != password) {
      return 'Passwords do not match.';
    }
    
    return null;
  }

  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return ErrorMessages.usernameRequired;
    }
    
    if (value.length < AppConstants.minUsernameLength ||
        value.length > AppConstants.maxUsernameLength) {
      return ErrorMessages.invalidUsername;
    }
    
    final RegExp usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(value)) {
      return ErrorMessages.invalidUsername;
    }
    
    return null;
  }

  static String? validateDisplayName(String? value) {
    if (value == null || value.isEmpty) {
      return ErrorMessages.displayNameRequired;
    }
    
    if (value.length > AppConstants.maxDisplayNameLength) {
      return 'Display name must be less than ${AppConstants.maxDisplayNameLength} characters long.';
    }
    
    return null;
  }

  static String? validateBio(String? value) {
    if (value != null && value.length > AppConstants.maxBioLength) {
      return 'Bio must be less than ${AppConstants.maxBioLength} characters long.';
    }
    
    return null;
  }

  static String? validateGroupName(String? value) {
    if (value == null || value.isEmpty) {
      return ErrorMessages.groupNameRequired;
    }
    
    if (value.length > AppConstants.maxGroupNameLength) {
      return 'Group name must be less than ${AppConstants.maxGroupNameLength} characters long.';
    }
    
    return null;
  }

  static String? validateGroupDescription(String? value) {
    if (value != null && value.length > AppConstants.maxGroupDescriptionLength) {
      return 'Group description must be less than ${AppConstants.maxGroupDescriptionLength} characters long.';
    }
    
    return null;
  }

  static String? validateMessage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return ErrorMessages.messageRequired;
    }
    
    if (value.length > AppConstants.maxMessageLength) {
      return 'Message must be less than ${AppConstants.maxMessageLength} characters long.';
    }
    
    return null;
  }

  static String? validateRequired(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required.';
    }
    
    return null;
  }

  static String? validateMinLength(String? value, int minLength, {String? fieldName}) {
    if (value == null || value.length < minLength) {
      return '${fieldName ?? 'This field'} must be at least $minLength characters long.';
    }
    
    return null;
  }

  static String? validateMaxLength(String? value, int maxLength, {String? fieldName}) {
    if (value != null && value.length > maxLength) {
      return '${fieldName ?? 'This field'} must be less than $maxLength characters long.';
    }
    
    return null;
  }

  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required.';
    }
    
    final RegExp phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
    if (!phoneRegex.hasMatch(value.replaceAll(RegExp(r'\s+'), ''))) {
      return 'Please enter a valid phone number.';
    }
    
    return null;
  }

  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    
    final RegExp urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );
    
    if (!urlRegex.hasMatch(value)) {
      return 'Please enter a valid URL.';
    }
    
    return null;
  }

  static bool isValidFileSize(int fileSize) {
    return fileSize <= AppConstants.maxFileSize;
  }

  static bool isValidImageSize(int imageSize) {
    return imageSize <= AppConstants.maxImageSize;
  }

  static bool isValidImageFormat(String fileName) {
    final String extension = fileName.split('.').last.toLowerCase();
    return AppConstants.supportedImageFormats.contains(extension);
  }

  static bool isValidFileFormat(String fileName) {
    final String extension = fileName.split('.').last.toLowerCase();
    return AppConstants.supportedFileFormats.contains(extension) ||
           AppConstants.supportedImageFormats.contains(extension);
  }

  static String? validateFileUpload(String fileName, int fileSize) {
    if (!isValidFileFormat(fileName)) {
      return ErrorMessages.unsupportedFileFormat;
    }
    
    if (!isValidFileSize(fileSize)) {
      return ErrorMessages.fileTooLarge;
    }
    
    return null;
  }

  static String? validateImageUpload(String fileName, int imageSize) {
    if (!isValidImageFormat(fileName)) {
      return 'Please select a valid image format (${AppConstants.supportedImageFormats.join(', ')}).';
    }
    
    if (!isValidImageSize(imageSize)) {
      return 'Image size must be less than ${(AppConstants.maxImageSize / (1024 * 1024)).toStringAsFixed(1)} MB.';
    }
    
    return null;
  }
}