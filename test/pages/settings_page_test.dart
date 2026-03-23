import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/pages/settings_page.dart';

void main() {
  // On macOS test platform, AppTheme.isApplePlatform returns true,
  // so CupertinoSwitch and Cupertino layout are used.
  Widget buildSettingsPage() {
    return MaterialApp(
      theme: ThemeData(platform: TargetPlatform.macOS),
      home: const SettingsPage(),
    );
  }

  group('SettingsPage', () {
    group('renders notification toggles', () {
      testWidgets('new problems toggle is present', (tester) async {
        await tester.pumpWidget(buildSettingsPage());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('settings_new_problems_toggle')),
          findsOneWidget,
        );
      });

      testWidgets('responder alerts toggle is present', (tester) async {
        await tester.pumpWidget(buildSettingsPage());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('settings_responder_alerts_toggle')),
          findsOneWidget,
        );
      });

      testWidgets('resolved alerts toggle is present', (tester) async {
        await tester.pumpWidget(buildSettingsPage());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('settings_resolved_alerts_toggle')),
          findsOneWidget,
        );
      });

      testWidgets('sound toggle is present', (tester) async {
        await tester.pumpWidget(buildSettingsPage());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('settings_sound_toggle')),
          findsOneWidget,
        );
      });

      testWidgets('haptics toggle is present', (tester) async {
        await tester.pumpWidget(buildSettingsPage());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('settings_haptics_toggle')),
          findsOneWidget,
        );
      });
    });

    group('renders display toggles', () {
      testWidgets('dark mode toggle is present', (tester) async {
        await tester.pumpWidget(buildSettingsPage());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('settings_dark_mode_toggle')),
          findsOneWidget,
        );
      });

      testWidgets('large text toggle is present', (tester) async {
        await tester.pumpWidget(buildSettingsPage());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('settings_large_text_toggle')),
          findsOneWidget,
        );
      });
    });

    group('renders data toggles', () {
      testWidgets('auto-refresh toggle is present', (tester) async {
        await tester.pumpWidget(buildSettingsPage());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('settings_auto_refresh_toggle')),
          findsOneWidget,
        );
      });
    });

    testWidgets('renders sign out button', (tester) async {
      await tester.pumpWidget(buildSettingsPage());
      await tester.pumpAndSettle();

      // Scroll down to reveal the sign out button
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings_sign_out_button')),
        200,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('settings_sign_out_button')),
        findsOneWidget,
      );
    });

    group('toggle behavior', () {
      testWidgets('new problems toggle starts on and can be toggled off',
          (tester) async {
        await tester.pumpWidget(buildSettingsPage());
        await tester.pumpAndSettle();

        // Starts as true (on)
        final switchFinder =
            find.byKey(const ValueKey('settings_new_problems_toggle'));
        final switchWidget =
            tester.widget<CupertinoSwitch>(switchFinder);
        expect(switchWidget.value, isTrue);

        // Tap to toggle off
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        final updatedSwitch =
            tester.widget<CupertinoSwitch>(switchFinder);
        expect(updatedSwitch.value, isFalse);
      });

      testWidgets('resolved alerts toggle starts off and can be toggled on',
          (tester) async {
        await tester.pumpWidget(buildSettingsPage());
        await tester.pumpAndSettle();

        final switchFinder =
            find.byKey(const ValueKey('settings_resolved_alerts_toggle'));
        final switchWidget =
            tester.widget<CupertinoSwitch>(switchFinder);
        expect(switchWidget.value, isFalse);

        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        final updatedSwitch =
            tester.widget<CupertinoSwitch>(switchFinder);
        expect(updatedSwitch.value, isTrue);
      });

      testWidgets('dark mode toggle starts off (light theme)',
          (tester) async {
        await tester.pumpWidget(buildSettingsPage());
        await tester.pumpAndSettle();

        final switchFinder =
            find.byKey(const ValueKey('settings_dark_mode_toggle'));
        final switchWidget =
            tester.widget<CupertinoSwitch>(switchFinder);
        expect(switchWidget.value, isFalse);
      });
    });

    group('uses CupertinoSwitch on Apple platform', () {
      testWidgets('toggles render as CupertinoSwitch', (tester) async {
        await tester.pumpWidget(buildSettingsPage());
        await tester.pumpAndSettle();

        // On macOS, all switches should be CupertinoSwitch
        expect(find.byType(CupertinoSwitch), findsNWidgets(8));
        expect(find.byType(Switch), findsNothing);
      });
    });

    group('section headers', () {
      testWidgets('renders notification, display, and data headers',
          (tester) async {
        await tester.pumpWidget(buildSettingsPage());
        await tester.pumpAndSettle();

        // AppListSection renders headers uppercased
        expect(find.text('NOTIFICATIONS'), findsOneWidget);
        expect(find.text('DISPLAY'), findsOneWidget);
        expect(find.text('DATA'), findsOneWidget);
      });

      testWidgets('renders about header after scrolling', (tester) async {
        await tester.pumpWidget(buildSettingsPage());
        await tester.pumpAndSettle();

        // About section may be offscreen; scroll to reveal it
        await tester.scrollUntilVisible(
          find.text('ABOUT'),
          200,
        );
        await tester.pumpAndSettle();

        expect(find.text('ABOUT'), findsOneWidget);
      });
    });
  });
}
