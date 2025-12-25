import 'package:flutter/material.dart';

class AppTheme {
  // Light theme colors
  static const Color primaryColor = Color(0xFF00A0B0);
  static const Color secondaryColor = Color(0xFF6ECACB);
  static const Color backgroundColor = Colors.white;
  static const Color textColor = Color(0xFF333333);
  static const Color lightGrayColor = Color(0xFFEEEEEE);
  static const Color mediumGrayColor = Color(0xFFCCCCCC);
  static const Color darkGrayColor = Color(0xFF888888);
  static const Color errorColor = Color(0xFFE74C3C);
  static const Color successColor = Color(0xFF2ECC71);

  // Dark theme colors
  static const Color darkPrimaryColor =
      Color(0xFF00A0B0); // Keep the same for brand consistency
  static const Color darkSecondaryColor =
      Color(0xFF6ECACB); // Keep the same for brand consistency
  static const Color darkBackgroundColor = Color(0xFF121219);
  static const Color darkSurfaceColor = Color(0xFF1E1E1E);
  static const Color darkAppBarColor =
      Color(0xFF00828F); // Slightly darker than primary for app bar
  static const Color darkTextColor = Colors.white;
  static const Color darkLightGrayColor = Color(0xFF2C2C2C);
  static const Color darkMediumGrayColor = Color(0xFF3C3C3C);
  static const Color darkDarkGrayColor = Color(0xFFAAAAAA);
  static const Color darkErrorColor = Color(0xFFE57373);
  static const Color darkSuccessColor = Color(0xFF81C784);
  static const Color darkInputBackgroundColor =
      Color(0xFF2C2C2C); // For input fields
  static const Color darkInputTextColor =
      Colors.white; // For text in input fields
  static const Color darkMessageBubbleColor =
      Color(0xFF1E1E1E); // For message bubbles
  static const Color darkMessageTextColor =
      Colors.white; // For text in message bubbles
  static const Color darkOutgoingMessageBubbleColor =
      Color(0xFF00828F); // For outgoing message bubbles

  // Text styles - Light Theme
  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textColor,
  );

  static const TextStyle subheadingStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textColor,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    color: textColor,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 14,
    color: darkGrayColor,
  );

  // Text styles - Dark Theme
  static const TextStyle darkHeadingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: darkTextColor,
  );

  static const TextStyle darkSubheadingStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: darkTextColor,
  );

  static const TextStyle darkBodyStyle = TextStyle(
    fontSize: 16,
    color: darkTextColor,
  );

  static const TextStyle darkCaptionStyle = TextStyle(
    fontSize: 14,
    color: darkDarkGrayColor,
  );

  // Button styles - Light Theme
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 15),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  static final ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    side: const BorderSide(color: primaryColor),
    padding: const EdgeInsets.symmetric(vertical: 15),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  // Button styles - Dark Theme
  static final ButtonStyle darkPrimaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: darkPrimaryColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 15),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  static final ButtonStyle darkSecondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: darkSecondaryColor,
    side: const BorderSide(color: darkSecondaryColor),
    padding: const EdgeInsets.symmetric(vertical: 15),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  // Input decoration - Light Theme
  static InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: lightGrayColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor),
      ),
    );
  }

  // Input decoration - Dark Theme
  static InputDecoration darkInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: darkDarkGrayColor),
      filled: true,
      fillColor: darkLightGrayColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: darkPrimaryColor),
      ),
    );
  }

  // Light theme
  static final ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: primaryButtonStyle,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: secondaryButtonStyle,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightGrayColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor),
      ),
    ),
    colorScheme: ColorScheme.fromSwatch().copyWith(
      primary: primaryColor,
      secondary: secondaryColor,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: mediumGrayColor,
    ),
    iconTheme: const IconThemeData(
      color: darkGrayColor,
    ),
    textTheme: const TextTheme(
      headlineLarge: headingStyle,
      headlineMedium: subheadingStyle,
      bodyLarge: bodyStyle,
      bodyMedium: bodyStyle,
      bodySmall: captionStyle,
    ),
    brightness: Brightness.light,
  );

  // Dark theme
  static final ThemeData darkTheme = ThemeData(
    primaryColor: darkPrimaryColor,
    scaffoldBackgroundColor: darkBackgroundColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkAppBarColor, // Updated app bar color for dark mode
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: darkPrimaryButtonStyle,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: darkSecondaryButtonStyle,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: darkSecondaryColor,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkInputBackgroundColor, // Updated for better visibility
      labelStyle: const TextStyle(color: darkDarkGrayColor),
      hintStyle: const TextStyle(color: darkDarkGrayColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: darkPrimaryColor),
      ),
    ),
    colorScheme: ColorScheme.fromSwatch(
      brightness: Brightness.dark,
    ).copyWith(
      primary: darkPrimaryColor,
      secondary: darkSecondaryColor,
      surface: darkSurfaceColor,
    ),
    cardTheme: CardThemeData(
      color: darkSurfaceColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: darkMediumGrayColor,
    ),
    iconTheme: const IconThemeData(
      color: darkDarkGrayColor,
    ),
    textTheme: const TextTheme(
      headlineLarge: darkHeadingStyle,
      headlineMedium: darkSubheadingStyle,
      bodyLarge: darkBodyStyle,
      bodyMedium: darkBodyStyle,
      bodySmall: darkCaptionStyle,
    ),
    switchTheme: SwitchThemeData(
      thumbColor:
          WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return darkSecondaryColor;
        }
        return darkMediumGrayColor;
      }),
      trackColor:
          WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return darkSecondaryColor.withValues(alpha: 0.5);
        }
        return darkMediumGrayColor.withValues(alpha: 0.5);
      }),
    ),
    brightness: Brightness.dark,
  );
}
