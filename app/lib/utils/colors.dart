import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF64B5F6);

  static const Color secondary = Color(0xFF03DAC6);
  static const Color secondaryDark = Color(0xFF018786);
  static const Color secondaryLight = Color(0xFF66FFF9);

  static const Color accent = Color(0xFFFF5722);
  static const Color accentDark = Color(0xFFD84315);
  static const Color accentLight = Color(0xFFFF8A65);

  static const Color background = Color(0xFFFAFAFA);
  static const Color backgroundDark = Color(0xFF121212);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  static const Color error = Color(0xFFB00020);
  static const Color errorDark = Color(0xFFCF6679);

  static const Color success = Color(0xFF4CAF50);
  static const Color successDark = Color(0xFF388E3C);

  static const Color doingGreen = Color(0xFF66BB6A);

  static const Color warning = Color(0xFFFF9800);
  static const Color warningDark = Color(0xFFF57C00);

  static const Color info = Color(0xFF2196F3);
  static const Color infoDark = Color(0xFF1976D2);

  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFF000000);
  static const Color onBackground = Color(0xFF000000);
  static const Color onBackgroundDark = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF000000);
  static const Color onSurfaceDark = Color(0xFFFFFFFF);
  static const Color onError = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF212121);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textSecondaryDark = Color(0xFFB3B3B3);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textHintDark = Color(0xFF666666);

  static const Color divider = Color(0xFFE0E0E0);
  static const Color dividerDark = Color(0xFF333333);

  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardBackgroundDark = Color(0xFF1E1E1E);

  static const Color inputBackground = Color(0xFFF5F5F5);
  static const Color inputBackgroundDark = Color(0xFF2A2A2A);

  static const Color buttonBackground = Color(0xFF2196F3);
  static const Color buttonBackgroundDark = Color(0xFF1976D2);

  static const Color chatBubbleOwn = Color(0xFF2196F3);
  static const Color chatBubbleOther = Color(0xFFE0E0E0);
  static const Color chatBubbleOtherDark = Color(0xFF333333);

  static const Color onlineIndicator = Color(0xFF4CAF50);
  static const Color offlineIndicator = Color(0xFF9E9E9E);

  // Google Brand Colors
  static const Color googleBlue = Color(0xFF4285f4);
  static const Color googleGreen = Color(0xFF34a853);
  static const Color googleYellow = Color(0xFFfbbc04);
  static const Color googleRed = Color(0xFFea4335);
  static const Color googleGrey = Color(0xFF9aa0a6);
  static const Color googleButtonBackground = Color(0xFFffffff);
  static const Color googleButtonText = Color(0xFF3c4043);
  static const Color googleButtonBorder = Color(0xFFdadce0);

  static const Color gradientStart = Color(0xFF2196F3);
  static const Color gradientEnd = Color(0xFF21CBF3);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FA)],
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
  );

  static const List<Color> avatarColors = [
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF673AB7),
    Color(0xFF3F51B5),
    Color(0xFF2196F3),
    Color(0xFF03A9F4),
    Color(0xFF00BCD4),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFF8BC34A),
    Color(0xFFCDDC39),
    Color(0xFFFFEB3B),
    Color(0xFFFFC107),
    Color(0xFFFF9800),
    Color(0xFFFF5722),
    Color(0xFF795548),
  ];

  static Color getAvatarColor(String text) {
    int hash = 0;
    for (int i = 0; i < text.length; i++) {
      hash = text.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return avatarColors[hash.abs() % avatarColors.length];
  }

  static MaterialColor createMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};
    // ignore: deprecated_member_use
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (double strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    // ignore: deprecated_member_use
    return MaterialColor(color.value, swatch);
  }
}
