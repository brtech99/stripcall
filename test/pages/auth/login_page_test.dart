import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/pages/auth/login_page.dart';

void main() {
  // LoginPage calls SupabaseManager in initState (_testSupabaseConnection).
  // That will throw since SupabaseManager isn't initialized, but the widget
  // handles it gracefully. We wrap in MaterialApp for theme/navigation context.
  Widget buildLoginPage() {
    return MaterialApp(
      home: const LoginPage(),
    );
  }

  group('LoginPage', () {
    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(buildLoginPage());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('login_password_field')), findsOneWidget);
    });

    testWidgets('renders login button', (tester) async {
      await tester.pumpWidget(buildLoginPage());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('login_submit_button')), findsOneWidget);
      expect(find.text('Login'), findsWidgets); // AppBar title + button
    });

    testWidgets('renders forgot password and create account buttons',
        (tester) async {
      await tester.pumpWidget(buildLoginPage());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('login_forgot_password_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('login_create_account_button')),
        findsOneWidget,
      );
    });

    group('email validation', () {
      testWidgets('shows error for empty email', (tester) async {
        await tester.pumpWidget(buildLoginPage());
        await tester.pumpAndSettle();

        // Enter valid password so only email fails
        await tester.enterText(
          find.byKey(const ValueKey('login_password_field')),
          'password123',
        );

        // Tap login
        await tester.tap(find.byKey(const ValueKey('login_submit_button')));
        await tester.pumpAndSettle();

        expect(find.text('Please enter your email'), findsOneWidget);
      });

      testWidgets('shows error for email without @', (tester) async {
        await tester.pumpWidget(buildLoginPage());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('login_email_field')),
          'notanemail',
        );
        await tester.enterText(
          find.byKey(const ValueKey('login_password_field')),
          'password123',
        );

        await tester.tap(find.byKey(const ValueKey('login_submit_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('Please enter a valid email address'),
          findsOneWidget,
        );
      });

      testWidgets('accepts valid email', (tester) async {
        await tester.pumpWidget(buildLoginPage());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('login_email_field')),
          'user@example.com',
        );
        await tester.enterText(
          find.byKey(const ValueKey('login_password_field')),
          'password123',
        );

        await tester.tap(find.byKey(const ValueKey('login_submit_button')));
        await tester.pumpAndSettle();

        // No email validation errors
        expect(find.text('Please enter your email'), findsNothing);
        expect(find.text('Please enter a valid email address'), findsNothing);
      });
    });

    group('password validation', () {
      testWidgets('shows error for empty password', (tester) async {
        await tester.pumpWidget(buildLoginPage());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('login_email_field')),
          'user@example.com',
        );
        // Leave password empty

        await tester.tap(find.byKey(const ValueKey('login_submit_button')));
        await tester.pumpAndSettle();

        expect(find.text('Please enter your password'), findsOneWidget);
      });
    });

    testWidgets('both validation errors show when both fields empty',
        (tester) async {
      await tester.pumpWidget(buildLoginPage());
      await tester.pumpAndSettle();

      // Tap login with both fields empty
      await tester.tap(find.byKey(const ValueKey('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });
  });
}
