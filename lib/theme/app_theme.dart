import 'package:flutter/material.dart';
import 'package:firstapp/other_utilities/lightness.dart';
import 'package:firstapp/theme/app_colours.dart';
import 'package:firstapp/providers_and_settings/program_provider.dart';

class AppTheme {
  static ThemeData get darkTheme {
    // --- Define Base Colors ---
    // Define the two distinct background colors
    const Color mainScaffoldBackground = Color(0XFF0e1415); // Your desired main background
    const Color widgetBackground = Color(0xFF1e2025);      // Your desired widget background

    const Color primary = primaryBlue;
    const Color onPrimary = textWhite;
    const Color secondary = accentOrange;
    const Color onSecondary = textWhite;
    const Color error = Colors.redAccent;
    const Color onError = textWhite;
    const Color onWidgetBackground = textWhite; // Text on widgetBackground

    // --- Calculate Variants (based on widget background) ---
    final Color primaryLight = lighten(primary, 20);
    final Color primaryDark = darken(primary, 20);
    // Use widgetBackground for variants used on widgets
    final Color widgetBackgroundLight = lighten(widgetBackground, 10);
    final Color widgetBackgroundDark = darken(widgetBackground, 20); // Or 40?
    final Color outlineColor = lighten(widgetBackground, 20); // Borders around widgets
    const Color subtleGreyColor = subtleGrey; // From app_colors.dart


    return ThemeData(
      //useMaterial3: true,
      brightness: Brightness.dark,

      // *** Set the main scaffold background color ***
      scaffoldBackgroundColor: mainScaffoldBackground,

      // --- Core Color Scheme ---
      // Adjust scheme based on the distinction
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: onSecondary,
        error: error,
        onError: onError,
        // Background refers to the main background behind scrollable content
        // Surface refers to the color of widgets like Cards, Sheets, Menus
        surface: widgetBackground, // *** Use widget color for surfaces ***
        onSurface: onWidgetBackground, // Text on widgets
        surfaceContainerHighest: widgetBackgroundLight, // Slightly lighter widgets
        onSurfaceVariant: onWidgetBackground,
        outline: outlineColor, // Borders for widgets
        // Central shadow token. On dark surfaces a shadow reads as a subtle
        // darkening, so keep it moderate. Every BoxShadow that uses
        // colorScheme.shadow inherits this, keeping shadows even everywhere.
        shadow: Colors.black.withValues(alpha: 0.5),
      ),

      // --- Component Theming (Ensure they use widget background) ---
      appBarTheme: const AppBarTheme(
        surfaceTintColor: Colors.transparent,
        // Usually matches widget background or a variant
        backgroundColor: widgetBackground,
        foregroundColor: onWidgetBackground,
        elevation: 1, // Maybe add slight elevation to distinguish from scaffold
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w900,
          color: onWidgetBackground,
          fontSize: 20,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
         // Keep consistent with AppBar or widget background
        backgroundColor: widgetBackground,
        indicatorColor: primary,
         labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
            (Set<WidgetState> states) {
              final bool isSelected = states.contains(WidgetState.selected);
              return TextStyle(
                color: isSelected ? primary : onWidgetBackground,
                fontWeight: FontWeight.w500,
                // fontFamily: 'YourDesiredFontFamily',
                // fontSize: 14.0,
              );
            }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
            (Set<WidgetState> states) => states.contains(WidgetState.selected)
                ? const IconThemeData(color: onPrimary) // Color inside the indicator
                : const IconThemeData(color: onWidgetBackground)), // Changed to onWidgetBackground (no opacity)
      ),

      listTileTheme: const ListTileThemeData(
         // Colors for text/icons within ListTiles (which are often on a surface)
         iconColor: onWidgetBackground,
         textColor: onWidgetBackground,
         contentPadding: EdgeInsets.only(left: 4, right: 16),
         // tileColor: widgetBackground // Optional: Explicitly set tile color if needed
      ),

      cardTheme: CardThemeData(
        // Explicitly set Card color to widget background
        color: widgetBackground,
        elevation: 0, // Or maybe 1-2 for slight separation
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
           side: BorderSide(color: outlineColor, width: 1), // Use outline color for border
        ),
      ),

      dialogTheme: DialogThemeData(
         backgroundColor: widgetBackground, // Dialogs should use widget background
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          // Maybe use a darker variant for input fields
          fillColor: widgetBackgroundDark,
          contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
          border: OutlineInputBorder(
             borderRadius: BorderRadius.circular(8.0),
             borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(8.0),
             // Border color relative to the input field's background
             borderSide: BorderSide(color: lighten(widgetBackgroundDark, 20)),
          ),
          focusedBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(8.0),
             borderSide: const BorderSide(color: primary, width: 2.0),
          ),
          hintStyle: TextStyle(color: onWidgetBackground.withOpacity(0.5)),
       ),

       popupMenuTheme: PopupMenuThemeData(
        color: mainScaffoldBackground, // Set the background color to match the scaffold
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0), // Optional: Customize the shape
        ),
        // You can also customize other properties like text style, elevation, etc.
      ),

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: accentOrange, // Your desired orange color
        contentTextStyle: TextStyle(color: textWhite), // White text
        actionTextColor: textWhite, // White color for action button text
      ),

      // ... (other themes like ElevatedButton, OutlinedButton, etc. likely don't need changes here) ...

      // --- Custom Theme Extensions ---
       extensions: <ThemeExtension<dynamic>>[
         AppColorExtensions(
           primaryLight: primaryLight,
           primaryDark: primaryDark,
           // Base these variants on the widget background color
           backgroundLight: widgetBackgroundLight,
           backgroundDark: widgetBackgroundDark,
           subtleGrey: subtleGreyColor,
           dayColors: Profile.colors,
         ),
       ],
    );
  }

  static ThemeData get lightTheme {
    // --- Define Base Colors ---
    const Color mainScaffoldBackground = Color(0xFFF5F5F5); // Light grey background
    const Color widgetBackground = Color(0xFFFFFFFF);      // Pure white for widgets

    const Color primary = primaryBlue;
    const Color onPrimary = textWhite;
    const Color secondary = accentOrange;
    const Color onSecondary = textWhite;
    const Color error = Colors.redAccent;
    const Color onError = textWhite;
    const Color onWidgetBackground = Color(0xFF333333); // Dark text on light widgets

    // --- Calculate Variants ---
    final Color primaryLight = lighten(primary, 20);
    final Color primaryDark = darken(primary, 20);
    final Color widgetBackgroundLight = darken(widgetBackground, 5); // Slightly darker for shadows
    final Color widgetBackgroundDark = darken(widgetBackground, 10); // For pressed states
    final Color outlineColor = darken(widgetBackground, 15); // Borders around widgets
    const Color subtleGreyColor = Color(0xFFE0E0E0); // Lighter subtle grey for light mode

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: mainScaffoldBackground,

      // --- Color Scheme ---
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: onSecondary,
        error: error,
        onError: onError,
        surface: widgetBackground,
        onSurface: onWidgetBackground,
        surfaceContainerHighest: widgetBackgroundLight,
        onSurfaceVariant: onWidgetBackground.withAlpha((0.8 * 255).round()),
        outline: outlineColor,
        // Central shadow token. On white surfaces an opaque shadow is harsh,
        // so keep it soft. Every BoxShadow that uses colorScheme.shadow
        // inherits this, keeping shadows even everywhere.
        shadow: Colors.black.withValues(alpha: 0.12),
      ),

      // --- Component Theming ---
      appBarTheme: const  AppBarTheme(
        surfaceTintColor: Colors.transparent,
        backgroundColor: widgetBackground,
        foregroundColor: onWidgetBackground,
        elevation: 1,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w900,
          color: onWidgetBackground,
          fontSize: 20,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: widgetBackground,
        indicatorColor: primary,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (Set<WidgetState> states) {
            return TextStyle(
              color: states.contains(WidgetState.selected) 
                  ? primary 
                  : onWidgetBackground,
              fontWeight: FontWeight.w500,
            );
          }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (Set<WidgetState> states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? onPrimary
                : onWidgetBackground,
          ),
      ),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: onWidgetBackground,
        textColor: onWidgetBackground,
        contentPadding: EdgeInsets.only(left: 4, right: 16),
      ),

      cardTheme: CardThemeData(
        color: widgetBackground,
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: outlineColor, width: 1),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: widgetBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: widgetBackground,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10.0, horizontal: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: outlineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: primary, width: 2.0),
        ),
        hintStyle: TextStyle(
          color: onWidgetBackground.withOpacity(0.5)),
      ),
      

      popupMenuTheme: PopupMenuThemeData(
        color: widgetBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0)),
      ),

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: secondary,
        contentTextStyle: TextStyle(color: onSecondary),
        actionTextColor: onSecondary,
      ),

      // --- Custom Theme Extensions ---
      extensions: <ThemeExtension<dynamic>>[
        AppColorExtensions(
          primaryLight: primaryLight,
          primaryDark: primaryDark,
          backgroundLight: widgetBackgroundLight,
          backgroundDark: widgetBackgroundDark,
          subtleGrey: subtleGreyColor,
          dayColors: Profile.colors,
        ),
      ],
    );
  }
}

// --- Define Custom Theme Extensions (AppColorExtensions definition remains the same) ---
@immutable
class AppColorExtensions extends ThemeExtension<AppColorExtensions> {
  // ... (Keep the existing AppColorExtensions class definition) ...
  const AppColorExtensions({
    required this.primaryLight,
    required this.primaryDark,
    required this.backgroundLight,
    required this.backgroundDark,
    required this.subtleGrey,
    required this.dayColors,
  });

  final Color primaryLight;
  final Color primaryDark;
  final Color backgroundLight;
  final Color backgroundDark;
  final Color subtleGrey;
  final List<Color> dayColors;

  @override
  AppColorExtensions copyWith({
    Color? primaryLight,
    Color? primaryDark,
    Color? backgroundLight,
    Color? backgroundDark,
    Color? subtleGrey,
    List<Color>? dayColors,
  }) {
    return AppColorExtensions(
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      backgroundLight: backgroundLight ?? this.backgroundLight,
      backgroundDark: backgroundDark ?? this.backgroundDark,
      subtleGrey: subtleGrey ?? this.subtleGrey,
      dayColors: dayColors ?? this.dayColors,
    );
  }

  @override
  AppColorExtensions lerp(ThemeExtension<AppColorExtensions>? other, double t) {
    if (other is! AppColorExtensions) {
      return this;
    }
    return AppColorExtensions(
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      backgroundLight: Color.lerp(backgroundLight, other.backgroundLight, t)!,
      backgroundDark: Color.lerp(backgroundDark, other.backgroundDark, t)!,
      subtleGrey: Color.lerp(subtleGrey, other.subtleGrey, t)!,
      dayColors: t < 0.5 ? dayColors : other.dayColors,
    );
  }
}