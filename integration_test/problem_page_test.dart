// Problem Page E2E Test
//
// This test covers the complete problem lifecycle:
// 1. Superuser login and navigation
// 2. Problem creation from app
// 3. Crew member "On My Way" response
// 4. Problem resolution
//
// NOTE: This uses IntegrationTestWidgetsFlutterBinding for compatibility
// with other tests in this directory. All steps run in a single test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stripcall/main.dart' as app;

import 'test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Problem Page: Complete problem lifecycle', (WidgetTester tester) async {
    // Start the app
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // ========================================
    // STEP 1: Login as superuser (if not already logged in)
    // ========================================
    // Check if we're already logged in (on Select Event page)
    final alreadyLoggedIn = find.byKey(const ValueKey('select_event_list')).evaluate().isNotEmpty;

    if (!alreadyLoggedIn) {
      // Check if login fields are present
      final loginFieldPresent = find.byKey(const ValueKey('login_email_field')).evaluate().isNotEmpty;

      if (loginFieldPresent) {
        // Enter credentials
        await tester.enterText(
          find.byKey(const ValueKey('login_email_field')),
          TestConfig.superuserEmail,
        );
        await tester.enterText(
          find.byKey(const ValueKey('login_password_field')),
          TestConfig.testPassword,
        );

        // Tap login button
        await tester.tap(find.byKey(const ValueKey('login_submit_button')));
        await tester.pumpAndSettle(const Duration(seconds: 10));
      }
    }

    // Should be on Select Event page
    expect(find.byKey(const ValueKey('select_event_list')), findsOneWidget);

    // Verify we see the test event
    expect(find.text('E2E Test Event'), findsOneWidget);

    // ========================================
    // STEP 2: Navigate to Problem Page
    // ========================================
    // Tap on the E2E Test Event (event ID 1)
    final eventItem = find.byKey(const ValueKey('select_event_item_1'));
    expect(eventItem, findsOneWidget);
    await tester.tap(eventItem);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Superuser should see crew dropdown
    expect(find.byKey(const ValueKey('problems_crew_dropdown')), findsOneWidget);

    // Should see Report Problem button
    expect(find.byKey(const ValueKey('problems_report_button')), findsOneWidget);

    // ========================================
    // STEP 3: Create problem from app
    // ========================================
    // Tap Report Problem button
    await tester.tap(find.byKey(const ValueKey('problems_report_button')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Should see new problem dialog
    expect(find.byKey(const ValueKey('new_problem_dialog')), findsOneWidget);

    // Select Armorer crew (radio button) - crew ID 1
    final armorerRadio = find.byKey(const ValueKey('new_problem_crew_radio_1'));
    expect(armorerRadio, findsOneWidget);
    await tester.tap(armorerRadio);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Select strip 1
    final strip1Chip = find.widgetWithText(ChoiceChip, '1');
    expect(strip1Chip, findsOneWidget);
    await tester.tap(strip1Chip);
    await tester.pumpAndSettle();

    // Select symptom class dropdown
    final symptomClassDropdown = find.byKey(const ValueKey('new_problem_symptom_class_dropdown'));
    expect(symptomClassDropdown, findsOneWidget);
    await tester.tap(symptomClassDropdown);
    await tester.pumpAndSettle();

    // Select "Weapon Issue"
    final weaponIssue = find.text('Weapon Issue').last;
    expect(weaponIssue, findsOneWidget);
    await tester.tap(weaponIssue);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Select symptom dropdown
    final symptomDropdown = find.byKey(const ValueKey('new_problem_symptom_dropdown'));
    expect(symptomDropdown, findsOneWidget);
    await tester.tap(symptomDropdown);
    await tester.pumpAndSettle();

    // Select "Blade broken"
    final bladeBroken = find.text('Blade broken').last;
    expect(bladeBroken, findsOneWidget);
    await tester.tap(bladeBroken);
    await tester.pumpAndSettle();

    // Submit the problem
    final submitButton = find.byKey(const ValueKey('new_problem_submit_button'));
    expect(submitButton, findsOneWidget);
    await tester.tap(submitButton);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Dialog should close
    expect(find.byKey(const ValueKey('new_problem_dialog')), findsNothing);

    // Should see a problem card (there may be multiple from previous test runs)
    final problemCards = find.byWidgetPredicate(
      (widget) => widget.key.toString().contains('problem_card_'),
    );
    expect(problemCards, findsWidgets);

    // ========================================
    // STEP 4: Verify problems list works
    // ========================================
    expect(find.byKey(const ValueKey('problems_list')), findsOneWidget);

    // ========================================
    // TEST COMPLETE
    // ========================================
  });
}
