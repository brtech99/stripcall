import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stripcall/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Simple E2E Tests', () {
    testWidgets('App launches and shows login page', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify login page is shown
      expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('login_password_field')), findsOneWidget);
    });

    testWidgets('Navigate to Create Account page', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Wait for login page
      expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);

      // Tap Create Account button
      await tester.tap(find.byKey(const ValueKey('login_create_account_button')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify we're on Create Account page
      expect(find.byKey(const ValueKey('register_firstname_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('register_lastname_field')), findsOneWidget);
    });
  });
}
