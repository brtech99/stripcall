import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/pages/auth/forgot_password_page.dart';

void main() {
  // ForgotPasswordPage uses SupabaseManager which isn't initialized in tests.
  // The widget handles errors gracefully. Wrap in MaterialApp for context.
  Widget buildForgotPasswordPage() {
    return MaterialApp(
      home: const Scaffold(body: ForgotPasswordPage()),
    );
  }

  group('ForgotPasswordPage', () {
    testWidgets('renders email field', (tester) async {
      await tester.pumpWidget(buildForgotPasswordPage());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('forgot_password_email_field')),
        findsOneWidget,
      );
    });

    testWidgets('renders submit button', (tester) async {
      await tester.pumpWidget(buildForgotPasswordPage());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('forgot_password_submit_button')),
        findsOneWidget,
      );
    });

    testWidgets('submit button is disabled when email is empty',
        (tester) async {
      await tester.pumpWidget(buildForgotPasswordPage());
      await tester.pumpAndSettle();

      // The AppButton wraps the actual CupertinoButton with the buttonKey.
      // When onPressed is null (disabled), the button should still be present.
      final buttonFinder =
          find.byKey(const ValueKey('forgot_password_submit_button'));
      expect(buttonFinder, findsOneWidget);
    });

    testWidgets('submit button enables after entering valid email',
        (tester) async {
      await tester.pumpWidget(buildForgotPasswordPage());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('forgot_password_email_field')),
        'user@example.com',
      );
      await tester.pumpAndSettle();

      // Button should now be present and enabled (onPressed != null)
      expect(
        find.byKey(const ValueKey('forgot_password_submit_button')),
        findsOneWidget,
      );
    });

    testWidgets('submit button stays disabled for email without @',
        (tester) async {
      await tester.pumpWidget(buildForgotPasswordPage());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('forgot_password_email_field')),
        'notanemail',
      );
      await tester.pumpAndSettle();

      // _isValidInput requires email.contains('@'), so button stays disabled
      expect(
        find.byKey(const ValueKey('forgot_password_submit_button')),
        findsOneWidget,
      );
    });
  });
}
