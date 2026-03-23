// Screenshot capture integration test
//
// Navigates through all non-superuser screens and captures screenshots.
// Run with:
//   flutter test integration_test/screenshot_test.dart --no-pub \
//     -d <SIMULATOR_ID> \
//     --dart-define="SUPABASE_URL=http://127.0.0.1:54321" \
//     --dart-define="SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stripcall/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  int screenshotIndex = 0;

  Future<void> takeScreenshot(String name) async {
    screenshotIndex++;
    final paddedIndex = screenshotIndex.toString().padLeft(2, '0');
    await binding.takeScreenshot('${paddedIndex}_$name');
  }

  Future<void> loginAs(WidgetTester tester, String email, String password) async {
    // Wait for login page
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);

    // Enter credentials
    await tester.enterText(
      find.byKey(const ValueKey('login_email_field')),
      email,
    );
    await tester.enterText(
      find.byKey(const ValueKey('login_password_field')),
      password,
    );

    // Tap login
    await tester.tap(find.byKey(const ValueKey('login_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  Future<void> logout(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('settings_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings_menu_logout')));
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }

  testWidgets('Capture all non-superuser screenshots', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // ── 1. Login Page ──
    await takeScreenshot('login_page');

    // ── 2. Forgot Password Page ──
    await tester.tap(find.byKey(const ValueKey('login_forgot_password_button')));
    await tester.pumpAndSettle();
    await takeScreenshot('forgot_password_page');
    // Go back
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();

    // ── 3. Create Account Page ──
    await tester.tap(find.byKey(const ValueKey('login_create_account_button')));
    await tester.pumpAndSettle();
    await takeScreenshot('create_account_page');
    // Go back
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();

    // ── 4. Login as armorer1 (crew chief) ──
    await loginAs(tester, 'e2e_armorer1@test.com', 'TestPassword123!');

    // ── 5. Select Event Page ──
    await takeScreenshot('select_event_page');

    // Select the seeded event
    await tester.tap(find.byKey(const ValueKey('select_event_list')).first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    // Tap the first event item in the list
    final eventItems = find.descendant(
      of: find.byKey(const ValueKey('select_event_list')),
      matching: find.byType(ListTile),
    );
    if (eventItems.evaluate().isNotEmpty) {
      await tester.tap(eventItems.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    // ── 6. Problems Page (empty) ──
    await takeScreenshot('problems_page_empty');

    // ── 7. New Problem Dialog ──
    await tester.tap(find.byKey(const ValueKey('problems_report_button')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await takeScreenshot('new_problem_dialog');

    // Fill in new problem and submit
    // Select strip (tap "1" text in the strip selector)
    final strip1 = find.text('1');
    if (strip1.evaluate().isNotEmpty) {
      await tester.tap(strip1.first);
      await tester.pumpAndSettle();
    }

    // Select symptom class dropdown
    final symptomClassDropdown = find.byKey(const ValueKey('new_problem_symptom_class_dropdown'));
    if (symptomClassDropdown.evaluate().isNotEmpty) {
      await tester.tap(symptomClassDropdown);
      await tester.pumpAndSettle();
      // Pick first option
      final options = find.byType(DropdownMenuItem);
      if (options.evaluate().length > 1) {
        await tester.tap(options.at(1));
        await tester.pumpAndSettle();
      }
    }

    // Select symptom dropdown
    final symptomDropdown = find.byKey(const ValueKey('new_problem_symptom_dropdown'));
    if (symptomDropdown.evaluate().isNotEmpty) {
      await tester.tap(symptomDropdown);
      await tester.pumpAndSettle();
      final options = find.byType(DropdownMenuItem);
      if (options.evaluate().length > 1) {
        await tester.tap(options.at(1));
        await tester.pumpAndSettle();
      }
    }

    await takeScreenshot('new_problem_dialog_filled');

    // Submit problem
    await tester.tap(find.byKey(const ValueKey('new_problem_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // ── 8. Problems Page (with a problem) ──
    await takeScreenshot('problems_page_with_problem');

    // Expand the problem card (tap on it)
    final problemsList = find.byKey(const ValueKey('problems_list'));
    if (problemsList.evaluate().isNotEmpty) {
      final cards = find.descendant(
        of: problemsList,
        matching: find.byType(GestureDetector),
      );
      if (cards.evaluate().isNotEmpty) {
        await tester.tap(cards.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }
    }
    await takeScreenshot('problem_expanded');

    // ── 9. Edit Symptom Dialog ──
    final editSymptomButton = find.text('Edit Symptom');
    if (editSymptomButton.evaluate().isNotEmpty) {
      await tester.tap(editSymptomButton.first);
      await tester.pumpAndSettle();
      await takeScreenshot('edit_symptom_dialog');
      // Cancel
      await tester.tap(find.byKey(const ValueKey('edit_symptom_cancel_button')));
      await tester.pumpAndSettle();
    }

    // ── 10. Resolve Problem Dialog ──
    final resolveButton = find.text('Resolve');
    if (resolveButton.evaluate().isNotEmpty) {
      await tester.tap(resolveButton.first);
      await tester.pumpAndSettle();
      await takeScreenshot('resolve_problem_dialog');
      // Cancel
      await tester.tap(find.byKey(const ValueKey('resolve_problem_cancel_button')));
      await tester.pumpAndSettle();
    }

    // ── 11. Settings Menu ──
    await tester.tap(find.byKey(const ValueKey('settings_menu_button')));
    await tester.pumpAndSettle();
    await takeScreenshot('settings_menu');

    // Close menu by tapping outside
    await tester.tapAt(const Offset(50, 300));
    await tester.pumpAndSettle();

    // ── 12. Account Page ──
    await tester.tap(find.byKey(const ValueKey('settings_menu_button')));
    await tester.pumpAndSettle();
    final accountMenuItem = find.byKey(const ValueKey('settings_menu_account'));
    if (accountMenuItem.evaluate().isNotEmpty) {
      await tester.tap(accountMenuItem);
      await tester.pumpAndSettle();
      await takeScreenshot('account_page');
      // Go back
      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton.first);
        await tester.pumpAndSettle();
      }
    }

    // Done! Logout
    await logout(tester);
    await takeScreenshot('logged_out');
  });
}
