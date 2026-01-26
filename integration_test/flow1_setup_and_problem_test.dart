// Flow 1: Complete Setup and Problem Flow
//
// This test covers:
// 1. Superuser creates event and assigns crew chiefs
// 2. Crew chiefs add crew members
// 3. Verify crew member access
// 4. Referee creates problem
// 5. Message visibility tests (include_reporter flag)
// 6. "On my way" responder flow

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:stripcall/main.dart' as app;

import 'test_config.dart';
import 'helpers/test_helpers.dart';

void main() {
  patrolTest(
    'Flow 1: Complete setup and problem flow',
    ($) async {
      // Start the app
      app.main();
      await $.pumpAndSettle();

      // ========================================
      // PART 1: Superuser creates event
      // ========================================

      // Login as superuser
      await login($, TestConfig.testUsers.superuser);

      // Navigate to Manage Events
      await openSettingsMenuItem($, const ValueKey('settings_menu_manage_events'));

      // Create new event
      await $(const ValueKey('manage_events_add_button')).tap();
      await $.pumpAndSettle();

      // Fill in event details
      await $(const ValueKey('manage_event_name_field')).enterText('E2E Test Event');
      await $(const ValueKey('manage_event_city_field')).enterText('Test City');
      await $(const ValueKey('manage_event_state_field')).enterText('TS');

      // Set start date (today)
      await $(const ValueKey('manage_event_start_date_button')).tap();
      await $.pumpAndSettle();
      await $(const Text('OK')).tap(); // Accept today's date
      await $.pumpAndSettle();

      // Set end date (tomorrow)
      await $(const ValueKey('manage_event_end_date_button')).tap();
      await $.pumpAndSettle();
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await $(Text(tomorrow.day.toString())).tap();
      await $(const Text('OK')).tap();
      await $.pumpAndSettle();

      // Set strip count
      await $(const ValueKey('manage_event_count_field')).enterText('10');

      // Save event
      await $(const ValueKey('manage_event_save_button')).tap();
      await $.pumpAndSettle();

      // Should navigate back to manage events list
      await $(const ValueKey('manage_events_list')).waitUntilVisible();

      // Tap on the event we just created
      await $(const Text('E2E Test Event')).tap();
      await $.pumpAndSettle();

      // ========================================
      // PART 2: Add Armorer crew with crew chief
      // ========================================

      await $(const ValueKey('manage_event_add_crew_button')).tap();
      await $.pumpAndSettle();

      // Select Armorer crew type from dropdown
      await $(const Text('Armorer')).tap();
      await $.pumpAndSettle();

      // Search and select armorer1 as crew chief
      await searchAndSelectUser($, 'Armorer', 'One');

      // ========================================
      // PART 3: Add Medical crew with crew chief
      // ========================================

      await $(const ValueKey('manage_event_add_crew_button')).tap();
      await $.pumpAndSettle();

      // Select Medical crew type
      await $(const Text('Medical')).tap();
      await $.pumpAndSettle();

      // Search and select medical1 as crew chief
      await searchAndSelectUser($, 'Medical', 'One');

      // Logout superuser
      await logout($);

      // ========================================
      // PART 4: Armorer1 (crew chief) adds armorer2
      // ========================================

      await login($, TestConfig.testUsers.armorer1);

      // Navigate to Manage Crews
      await openSettingsMenuItem($, const ValueKey('settings_menu_manage_crews'));

      // Select the crew (E2E Test Event - Armorer)
      await $(const Text('E2E Test Event')).tap();
      await $.pumpAndSettle();

      // Add crew member
      await $(const ValueKey('manage_crew_add_member_button')).tap();
      await $.pumpAndSettle();

      // Search and select armorer2
      await searchAndSelectUser($, 'Armorer', 'Two');

      // Verify armorer2 appears in list
      await $(const Text('Armorer Two')).waitUntilVisible();

      await logout($);

      // ========================================
      // PART 5: Medical1 (crew chief) adds medical2
      // ========================================

      await login($, TestConfig.testUsers.medical1);

      // Navigate to Manage Crews
      await openSettingsMenuItem($, const ValueKey('settings_menu_manage_crews'));

      // Select the crew
      await $(const Text('E2E Test Event')).tap();
      await $.pumpAndSettle();

      // Add crew member
      await $(const ValueKey('manage_crew_add_member_button')).tap();
      await $.pumpAndSettle();

      // Search and select medical2
      await searchAndSelectUser($, 'Medical', 'Two');

      // Verify medical2 appears in list
      await $(const Text('Medical Two')).waitUntilVisible();

      await logout($);

      // ========================================
      // PART 6: Verify crew member access
      // ========================================

      // Login as medical2 and verify sees Medical crew
      await login($, TestConfig.testUsers.medical2);
      await selectEvent($, 'E2E Test Event');

      // Should see Medical in header
      await $(const Text('Medical')).waitUntilVisible();

      // Verify no problems yet
      await $(const Text('No problems reported yet')).waitUntilVisible();

      await logout($);

      // Login as armorer2 and verify sees Armorer crew
      await login($, TestConfig.testUsers.armorer2);
      await selectEvent($, 'E2E Test Event');

      // Should see Armorer in header
      await $(const Text('Armorer')).waitUntilVisible();

      await logout($);

      // ========================================
      // PART 7: Referee creates problem for Armorer
      // ========================================

      await login($, TestConfig.testUsers.referee1);
      await selectEvent($, 'E2E Test Event');

      // Report a problem
      await $(const ValueKey('problems_report_button')).tap();
      await $(const ValueKey('new_problem_dialog')).waitUntilVisible();

      // Select Armorer crew
      await $(const Text('Armorer')).tap();
      await $.pumpAndSettle();

      // Select strip 1
      await $(const Text('1')).tap();

      // Select symptom class
      await $(const ValueKey('new_problem_symptom_class_dropdown')).tap();
      await $(const Text('Weapon Issue')).tap();
      await $.pumpAndSettle();

      // Select symptom
      await $(const ValueKey('new_problem_symptom_dropdown')).tap();
      await $(const Text('Blade broken')).tap();
      await $.pumpAndSettle();

      // Submit
      await $(const ValueKey('new_problem_submit_button')).tap();
      await $.pumpAndSettle();

      // Verify problem appears in referee's list
      await $(const Text('Strip 1: Blade broken')).waitUntilVisible();

      await logout($);

      // ========================================
      // PART 8: Armorer1 sends message WITH include_reporter
      // ========================================

      await login($, TestConfig.testUsers.armorer1);
      await selectEvent($, 'E2E Test Event');

      // Verify problem appears
      await $(const Text('Strip 1: Blade broken')).waitUntilVisible();

      // Expand the problem card to see chat
      await $(const Text('Strip 1: Blade broken')).tap();
      await $.pumpAndSettle();

      // Type and send a message (include_reporter is checked by default)
      final messageField1 = find.byType(TextField).last;
      await $.tester.enterText(messageField1, 'Message visible to referee');
      await $.pumpAndSettle();

      // Tap send button
      await $(const Icon(Icons.send)).tap();
      await $.pumpAndSettle();

      await logout($);

      // ========================================
      // PART 9: Armorer2 sends message WITHOUT include_reporter
      // ========================================

      await login($, TestConfig.testUsers.armorer2);
      await selectEvent($, 'E2E Test Event');

      // Expand problem
      await $(const Text('Strip 1: Blade broken')).tap();
      await $.pumpAndSettle();

      // Uncheck include_reporter checkbox
      final checkbox = find.byType(Checkbox);
      await $.tester.tap(checkbox);
      await $.pumpAndSettle();

      // Type and send message
      final messageField2 = find.byType(TextField).last;
      await $.tester.enterText(messageField2, 'Internal crew message');
      await $.pumpAndSettle();

      await $(const Icon(Icons.send)).tap();
      await $.pumpAndSettle();

      await logout($);

      // ========================================
      // PART 10: Verify referee sees only include_reporter message
      // ========================================

      await login($, TestConfig.testUsers.referee1);
      await selectEvent($, 'E2E Test Event');

      // Expand problem
      await $(const Text('Strip 1: Blade broken')).tap();
      await $.pumpAndSettle();

      // Should see the first message (with include_reporter)
      await $(const Text('Message visible to referee')).waitUntilVisible();

      // Should NOT see the internal message
      expect($(const Text('Internal crew message')).exists, isFalse);

      await logout($);

      // ========================================
      // PART 11: Armorer1 clicks "On my way"
      // ========================================

      await login($, TestConfig.testUsers.armorer1);
      await selectEvent($, 'E2E Test Event');

      // Expand problem to see buttons
      await $(const Text('Strip 1: Blade broken')).tap();
      await $.pumpAndSettle();

      // Click "On my way"
      await $(const Text('On my way')).tap();
      await $.pumpAndSettle();

      // Verify button changed to "En route"
      await $(const Text('En route')).waitUntilVisible();

      // Verify "On my way" button is no longer visible
      expect($(const Text('On my way')).exists, isFalse);

      await logout($);

      // ========================================
      // TEST COMPLETE
      // ========================================
    },
  );
}
