import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// Main theme configuration for the app.
///
/// iOS: Apple HIG with blue (#007AFF) primary accent.
/// Android/Web: Material Design 3 with purple (#6750A4) seed.
class AppTheme {
  AppTheme._();

  // ==========================================================================
  // Light Theme (Material Design 3 — purple seed)
  // ==========================================================================

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.md3Primary,
      brightness: Brightness.light,
      primary: AppColors.md3Primary,
      onPrimary: AppColors.md3OnPrimary,
      surface: AppColors.md3Surface,
      onSurface: AppColors.md3OnSurface,
      onSurfaceVariant: AppColors.md3OnSurfaceVariant,
      surfaceContainerHighest: AppColors.md3SurfaceContainerHigh,
      error: AppColors.md3Error,
      outline: AppColors.md3Outline,
      secondaryContainer: AppColors.md3SecondaryContainer,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colorScheme.surface,

      // AppBar
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.md3SurfaceContainer,
        foregroundColor: AppColors.md3OnSurface,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w400,
          color: AppColors.md3OnSurface,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.md3SurfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusLg,
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // Elevated Button — full pill
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(0, 52),
          shape: const StadiumBorder(),
          backgroundColor: AppColors.md3Primary,
          foregroundColor: AppColors.md3OnPrimary,
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: AppSpacing.buttonPadding,
          shape: const StadiumBorder(),
        ),
      ),

      // Outlined Button — full pill
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(0, 52),
          shape: const StadiumBorder(),
        ),
      ),

      // Input Decoration — outlined, 4dp radius
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: AppSpacing.formFieldPadding,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),

      // List Tile
      listTileTheme: ListTileThemeData(
        contentPadding: AppSpacing.listItemPadding,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusMd,
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),

      // Bottom Sheet — 28dp top corners
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusMd,
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: colorScheme.outlineVariant,
      ),

      // Chip — full pill
      chipTheme: const ChipThemeData(
        shape: StadiumBorder(),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: AppColors.md3Primary,
        foregroundColor: AppColors.md3OnPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusLg,
        ),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.md3OnPrimary;
          }
          return AppColors.md3Outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.md3Primary;
          }
          return AppColors.md3SurfaceContainerHigh;
        }),
      ),

      // Popup Menu
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusMd,
        ),
      ),

      // Dropdown
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // Dark Theme (Material Design 3 — purple seed, dark)
  // ==========================================================================

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.md3Primary,
      brightness: Brightness.dark,
      primary: AppColors.md3PrimaryDark,
      onPrimary: AppColors.md3OnPrimaryDark,
      surface: AppColors.md3SurfaceDark,
      onSurface: AppColors.md3OnSurfaceDark,
      onSurfaceVariant: AppColors.md3OnSurfaceVariantDark,
      error: AppColors.md3ErrorDark,
      outline: AppColors.md3OutlineDark,
      secondaryContainer: AppColors.md3SecondaryContainerDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,

      // AppBar
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.md3SurfaceContainerDark,
        foregroundColor: AppColors.md3OnSurfaceDark,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w400,
          color: AppColors.md3OnSurfaceDark,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.md3SurfaceContainerHighDark,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusLg,
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // Elevated Button — full pill
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(0, 52),
          shape: const StadiumBorder(),
          backgroundColor: AppColors.md3PrimaryDark,
          foregroundColor: AppColors.md3OnPrimaryDark,
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: AppSpacing.buttonPadding,
          shape: const StadiumBorder(),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(0, 52),
          shape: const StadiumBorder(),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: AppSpacing.formFieldPadding,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),

      // List Tile
      listTileTheme: ListTileThemeData(
        contentPadding: AppSpacing.listItemPadding,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusMd,
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusMd,
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: colorScheme.outlineVariant,
      ),

      // Chip
      chipTheme: const ChipThemeData(shape: StadiumBorder()),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: AppColors.md3PrimaryDark,
        foregroundColor: AppColors.md3OnPrimaryDark,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusLg,
        ),
      ),

      // Popup Menu
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusMd,
        ),
      ),

      // Dropdown
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // iOS-specific Light Theme (used when wrapping with CupertinoTheme)
  // ==========================================================================

  static ThemeData get iosLightTheme {
    // Start from the MD3 light theme and override for iOS
    final base = lightTheme;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.iosBlue,
        onPrimary: Colors.white,
        surface: AppColors.iosBackground,
        onSurface: AppColors.iosTextPrimary,
        onSurfaceVariant: AppColors.iosTextSecondary,
        error: AppColors.iosRed,
        outline: AppColors.iosSeparator,
        outlineVariant: AppColors.iosSeparator,
      ),
      scaffoldBackgroundColor: AppColors.iosBackground,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: AppColors.iosSurface,
        foregroundColor: AppColors.iosTextPrimary,
      ),
      cardTheme: base.cardTheme.copyWith(color: AppColors.iosSurface),
    );
  }

  static ThemeData get iosDarkTheme {
    final base = darkTheme;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.iosBlue,
        onPrimary: Colors.white,
        surface: AppColors.iosBackgroundDark,
        onSurface: AppColors.iosTextPrimaryDark,
        onSurfaceVariant: AppColors.iosTextSecondaryDark,
        error: AppColors.iosRed,
        outline: AppColors.iosSeparatorDark,
        outlineVariant: AppColors.iosSeparatorDark,
      ),
      scaffoldBackgroundColor: AppColors.iosBackgroundDark,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: AppColors.iosSurfaceDark,
        foregroundColor: AppColors.iosTextPrimaryDark,
      ),
      cardTheme: base.cardTheme.copyWith(color: AppColors.iosSurfaceDark),
    );
  }

  // ==========================================================================
  // Cupertino Theme
  // ==========================================================================

  static CupertinoThemeData get cupertinoLightTheme {
    return const CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.iosBlue,
    );
  }

  static CupertinoThemeData get cupertinoDarkTheme {
    return const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.iosBlue,
    );
  }

  // ==========================================================================
  // Helpers
  // ==========================================================================

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static bool isApplePlatform(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  static bool isAndroid(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.android;

  static CupertinoThemeData getCupertinoTheme(BuildContext context) =>
      isDark(context) ? cupertinoDarkTheme : cupertinoLightTheme;
}
