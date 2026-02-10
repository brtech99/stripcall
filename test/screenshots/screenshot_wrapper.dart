import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:stripcall/theme/theme.dart';

/// Wrapper for rendering screens in isolation for screenshots.
/// Supports both Material (Android) and Cupertino (iOS) rendering.
class ScreenshotWrapper extends StatelessWidget {
  final Widget child;
  final TargetPlatform platform;
  final bool isDarkMode;
  final Size screenSize;

  const ScreenshotWrapper({
    super.key,
    required this.child,
    this.platform = TargetPlatform.android,
    this.isDarkMode = false,
    this.screenSize = const Size(390, 844), // iPhone 14 size
  });

  /// Create a Material (Android) themed wrapper
  factory ScreenshotWrapper.material({
    required Widget child,
    bool isDarkMode = false,
    Size screenSize = const Size(390, 844),
  }) {
    return ScreenshotWrapper(
      platform: TargetPlatform.android,
      isDarkMode: isDarkMode,
      screenSize: screenSize,
      child: child,
    );
  }

  /// Create a Cupertino (iOS) themed wrapper
  factory ScreenshotWrapper.cupertino({
    required Widget child,
    bool isDarkMode = false,
    Size screenSize = const Size(390, 844),
  }) {
    return ScreenshotWrapper(
      platform: TargetPlatform.iOS,
      isDarkMode: isDarkMode,
      screenSize: screenSize,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;
    
    // Override the platform in the theme
    final themedData = theme.copyWith(
      platform: platform,
    );

    return MediaQuery(
      data: MediaQueryData(
        size: screenSize,
        devicePixelRatio: 3.0,
        platformBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themedData,
        darkTheme: AppTheme.darkTheme.copyWith(platform: platform),
        themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: child,
      ),
    );
  }
}

/// Extension to easily capture both platform variants
extension ScreenshotVariants on Widget {
  Widget wrapForMaterialScreenshot({bool isDarkMode = false}) {
    return ScreenshotWrapper.material(child: this, isDarkMode: isDarkMode);
  }

  Widget wrapForCupertinoScreenshot({bool isDarkMode = false}) {
    return ScreenshotWrapper.cupertino(child: this, isDarkMode: isDarkMode);
  }
}
