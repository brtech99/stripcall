import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stripcall/main.dart' as app;

import 'test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Smoke Tests', () {
    testWidgets('Login and logout flow', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Wait for login page
      expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);

      // Login as referee1
      await tester.enterText(
        find.byKey(const ValueKey('login_email_field')),
        TestConfig.testUsers.referee1.email,
      );
      await tester.enterText(
        find.byKey(const ValueKey('login_password_field')),
        TestConfig.testUsers.referee1.password,
      );
      await tester.tap(find.byKey(const ValueKey('login_submit_button')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify we're on the select event page
      expect(find.byKey(const ValueKey('select_event_list')), findsOneWidget);

      // Logout
      await tester.tap(find.byKey(const ValueKey('settings_menu_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings_menu_logout')));
      await tester.pumpAndSettle();

      // Verify we're back on login page
      expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);
    });
  });
}
