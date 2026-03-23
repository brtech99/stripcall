import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/pages/auth/create_account_page.dart';

void main() {
  // CreateAccountPage uses SupabaseManager which isn't initialized in tests.
  // The widget handles errors gracefully. Wrap in MaterialApp for context.
  Widget buildCreateAccountPage() {
    return MaterialApp(
      home: const CreateAccountPage(),
    );
  }

  group('CreateAccountPage', () {
    testWidgets('renders all form fields', (tester) async {
      await tester.pumpWidget(buildCreateAccountPage());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('register_firstname_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('register_lastname_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('register_phone_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('register_email_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('register_password_field')),
        findsOneWidget,
      );
    });

    testWidgets('renders submit button', (tester) async {
      await tester.pumpWidget(buildCreateAccountPage());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('register_submit_button')),
        findsOneWidget,
      );
    });

    testWidgets('renders sign in link', (tester) async {
      await tester.pumpWidget(buildCreateAccountPage());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('register_signin_button')),
        findsOneWidget,
      );
    });

    group('first name validation', () {
      testWidgets('shows error for empty first name', (tester) async {
        await tester.pumpWidget(buildCreateAccountPage());
        await tester.pumpAndSettle();

        // Fill all fields except first name
        await tester.enterText(
          find.byKey(const ValueKey('register_lastname_field')),
          'Doe',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_phone_field')),
          '5551234567',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_email_field')),
          'test@example.com',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_password_field')),
          'password123',
        );

        await tester.tap(find.byKey(const ValueKey('register_submit_button')));
        await tester.pumpAndSettle();

        expect(find.text('Please enter your first name'), findsOneWidget);
      });
    });

    group('last name validation', () {
      testWidgets('shows error for empty last name', (tester) async {
        await tester.pumpWidget(buildCreateAccountPage());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('register_firstname_field')),
          'John',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_phone_field')),
          '5551234567',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_email_field')),
          'test@example.com',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_password_field')),
          'password123',
        );

        await tester.tap(find.byKey(const ValueKey('register_submit_button')));
        await tester.pumpAndSettle();

        expect(find.text('Please enter your last name'), findsOneWidget);
      });
    });

    group('phone validation', () {
      testWidgets('shows error for empty phone', (tester) async {
        await tester.pumpWidget(buildCreateAccountPage());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('register_firstname_field')),
          'John',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_lastname_field')),
          'Doe',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_email_field')),
          'test@example.com',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_password_field')),
          'password123',
        );

        await tester.tap(find.byKey(const ValueKey('register_submit_button')));
        await tester.pumpAndSettle();

        expect(find.text('Please enter your phone number'), findsOneWidget);
      });

      testWidgets('shows error for short phone number', (tester) async {
        await tester.pumpWidget(buildCreateAccountPage());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('register_firstname_field')),
          'John',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_lastname_field')),
          'Doe',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_phone_field')),
          '555',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_email_field')),
          'test@example.com',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_password_field')),
          'password123',
        );

        await tester.tap(find.byKey(const ValueKey('register_submit_button')));
        await tester.pumpAndSettle();

        expect(find.text('Please enter a valid phone number'), findsOneWidget);
      });
    });

    group('email validation', () {
      testWidgets('shows error for empty email', (tester) async {
        await tester.pumpWidget(buildCreateAccountPage());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('register_firstname_field')),
          'John',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_lastname_field')),
          'Doe',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_phone_field')),
          '5551234567',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_password_field')),
          'password123',
        );

        await tester.tap(find.byKey(const ValueKey('register_submit_button')));
        await tester.pumpAndSettle();

        expect(find.text('Please enter your email'), findsOneWidget);
      });

      testWidgets('shows error for invalid email', (tester) async {
        await tester.pumpWidget(buildCreateAccountPage());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('register_firstname_field')),
          'John',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_lastname_field')),
          'Doe',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_phone_field')),
          '5551234567',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_email_field')),
          'notanemail',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_password_field')),
          'password123',
        );

        await tester.tap(find.byKey(const ValueKey('register_submit_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('Please enter a valid email address'),
          findsOneWidget,
        );
      });
    });

    group('password validation', () {
      testWidgets('shows error for empty password', (tester) async {
        await tester.pumpWidget(buildCreateAccountPage());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('register_firstname_field')),
          'John',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_lastname_field')),
          'Doe',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_phone_field')),
          '5551234567',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_email_field')),
          'test@example.com',
        );

        await tester.tap(find.byKey(const ValueKey('register_submit_button')));
        await tester.pumpAndSettle();

        expect(find.text('Please enter a password'), findsOneWidget);
      });

      testWidgets('shows error for short password', (tester) async {
        await tester.pumpWidget(buildCreateAccountPage());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('register_firstname_field')),
          'John',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_lastname_field')),
          'Doe',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_phone_field')),
          '5551234567',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_email_field')),
          'test@example.com',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register_password_field')),
          'short',
        );

        await tester.tap(find.byKey(const ValueKey('register_submit_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('Password must be at least 8 characters'),
          findsOneWidget,
        );
      });
    });

    testWidgets('all validation errors show when all fields empty',
        (tester) async {
      await tester.pumpWidget(buildCreateAccountPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('register_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your first name'), findsOneWidget);
      expect(find.text('Please enter your last name'), findsOneWidget);
      expect(find.text('Please enter your phone number'), findsOneWidget);
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
    });
  });
}
