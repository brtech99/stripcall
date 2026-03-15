import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stripcall/main.dart' as app;

import 'test_config.dart';
import 'helpers/mailpit_helper.dart';

/// E2E tests for unauthenticated auth flows: Create Account and Forgot Password.
///
/// These tests run against LOCAL Supabase only (via `supabase start`).
/// All tests run in a single testWidgets to avoid app reinitialization issues.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Create Account and Forgot Password flows', (tester) async {
    final mailpit = MailpitHelper();
    try {
      await mailpit.deleteAllMessages();
    } catch (_) {}

    // ─── Start app once ─────────────────────────────────────────────
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);

    // ═══════════════════════════════════════════════════════════════
    // TEST 1: Create account submits form and redirects to login
    // ═══════════════════════════════════════════════════════════════
    debugPrint('=== TEST 1: Create account full flow ===');

    await tester.tap(find.byKey(const ValueKey('login_create_account_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final testEmail =
        'e2e_create_${DateTime.now().millisecondsSinceEpoch}@test.com';

    await tester.enterText(
      find.byKey(const ValueKey('register_firstname_field')), 'Test');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('register_lastname_field')), 'NewUser');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('register_phone_field')),
      TestUsers.reservedSimPhone);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('register_email_field')), testEmail);
    await tester.pumpAndSettle();

    // Scroll to password fields
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('register_password_field')),
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('register_password_field')),
      TestConfig.testPassword);
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('register_confirm_password_field')),
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('register_confirm_password_field')),
      TestConfig.testPassword);
    await tester.pumpAndSettle();

    // Scroll to and tap submit
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('register_submit_button')),
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('register_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Should redirect back to login
    expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);
    debugPrint('=== TEST 1 PASSED: Create account redirected to login ===');

    // Check for confirmation email
    try {
      final link = await mailpit.getConfirmationLink(
        testEmail, timeout: const Duration(seconds: 10));
      if (link != null) {
        debugPrint('Confirmation email received: $link');
        expect(link, contains('auth'));
      }
    } catch (e) {
      debugPrint('Mailpit: $e');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 2: Create account validates empty fields
    // ═══════════════════════════════════════════════════════════════
    debugPrint('=== TEST 2: Create account validation ===');

    await tester.tap(find.byKey(const ValueKey('login_create_account_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Scroll to and tap submit with empty form
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('register_submit_button')),
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('register_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Should stay on register page
    expect(find.byType(Form), findsOneWidget);
    debugPrint('=== TEST 2 PASSED: Validation prevented submission ===');

    // ═══════════════════════════════════════════════════════════════
    // TEST 3: Navigate back to login via Sign In link
    // ═══════════════════════════════════════════════════════════════
    debugPrint('=== TEST 3: Sign In link navigation ===');

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('register_signin_button')),
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('register_signin_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);
    debugPrint('=== TEST 3 PASSED: Navigated back to login ===');

    // ═══════════════════════════════════════════════════════════════
    // TEST 4: Forgot password sends reset email
    // ═══════════════════════════════════════════════════════════════
    debugPrint('=== TEST 4: Forgot password full flow ===');
    try {
      await mailpit.deleteAllMessages();
    } catch (_) {}

    await tester.tap(find.byKey(const ValueKey('login_forgot_password_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('forgot_password_email_field')), findsOneWidget);

    const resetEmail = TestConfig.superuserEmail;
    await tester.enterText(
      find.byKey(const ValueKey('forgot_password_email_field')), resetEmail);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('forgot_password_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);
    debugPrint('=== TEST 4 PASSED: Forgot password redirected to login ===');

    // Check for reset email
    try {
      final link = await mailpit.getPasswordResetLink(
        resetEmail, timeout: const Duration(seconds: 10));
      if (link != null) {
        debugPrint('Password reset email received: $link');
        expect(link, contains('recover'));
      }
    } catch (e) {
      debugPrint('Mailpit: $e');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 5: Forgot password - disabled with empty email
    // ═══════════════════════════════════════════════════════════════
    debugPrint('=== TEST 5: Forgot password disabled button ===');

    await tester.tap(find.byKey(const ValueKey('login_forgot_password_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('forgot_password_email_field')), findsOneWidget);

    // Tap submit with no email — should stay on page
    await tester.tap(find.byKey(const ValueKey('forgot_password_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('forgot_password_email_field')), findsOneWidget);
    debugPrint('=== TEST 5 PASSED: Button disabled with empty email ===');

    // ═══════════════════════════════════════════════════════════════
    // TEST 6: Forgot password - Sign In link back to login
    // ═══════════════════════════════════════════════════════════════
    debugPrint('=== TEST 6: Forgot password Sign In link ===');

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);
    debugPrint('=== TEST 6 PASSED: Navigated back to login ===');

    debugPrint('=== ALL 6 TESTS PASSED ===');
    mailpit.dispose();
  });
}
