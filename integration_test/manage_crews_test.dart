import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stripcall/main.dart' as app;

import 'test_config.dart';

/// Manage Crews Test
///
/// Exercises crew member management across different user roles:
/// superuser (sees all crews), crew chief (sees own crew only),
/// regular user (no access to Manage Crews).
///
/// Prerequisites:
/// - Local Supabase is running with seed data (supabase db reset)
/// - Docker running
///
/// Seed data provides:
/// - E2E Test Event with Armorer crew (chief: Armorer One, member: Armorer Two)
///   and Medical crew (chief: Medical One, member: Medical Two)
///
/// Run with:
/// ```bash
/// flutter test integration_test/manage_crews_test.dart --no-pub \
///   -d <SIMULATOR_ID> --timeout=none \
///   --dart-define="SUPABASE_URL=http://127.0.0.1:54321" \
///   --dart-define="SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
///   --dart-define="SKIP_NOTIFICATIONS=true"
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Manage Crews Tests', () {
    testWidgets('Crew member management across user roles', (
      WidgetTester tester,
    ) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // ====================================================================
      // PRE-STEP: Ensure clean state (logout if already logged in)
      // ====================================================================
      debugPrint('=== PRE-STEP: Ensuring clean state ===');
      final settingsButton = find.byKey(const ValueKey('settings_menu_button'));
      if (settingsButton.evaluate().isNotEmpty) {
        await tester.tap(settingsButton);
        await tester.pumpAndSettle();
        final logoutButton = find.byKey(const ValueKey('settings_menu_logout'));
        if (logoutButton.evaluate().isNotEmpty) {
          await tester.tap(logoutButton);
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
        }
      }

      // ====================================================================
      // STEP 1: Login as superuser
      // ====================================================================
      debugPrint('=== STEP 1: Login as superuser ===');
      print('>>> STEP 1: Login as superuser');
      await _login(tester, TestConfig.testUsers.superuser);

      // ====================================================================
      // STEP 2: Navigate to Manage Crews via settings menu
      // ====================================================================
      debugPrint('=== STEP 2: Navigate to Manage Crews ===');
      print('>>> STEP 2: Navigate to Manage Crews');
      await tester.tap(find.byKey(const ValueKey('settings_menu_button')));
      await _pumpForDuration(tester, const Duration(seconds: 1));
      await tester.tap(
        find.byKey(const ValueKey('settings_menu_manage_crews')),
      );
      await _pumpForDuration(tester, const Duration(seconds: 3));

      // ====================================================================
      // STEP 3: Verify both seed crews are visible (superuser sees all)
      // ====================================================================
      debugPrint('=== STEP 3: Verify seed crews visible ===');
      print('>>> STEP 3: Verify seed crews visible');
      final crewList = find.byKey(const ValueKey('select_crew_list'));
      expect(crewList, findsOneWidget, reason: 'Crew list should be visible');

      // Seed data: E2E Test Event has Armorer and Medical crews
      // Subtitle is "Armorer Crew\n<dates>" so use textContaining
      final armorerCrewText = find.textContaining('Armorer Crew');
      final medicalCrewText = find.textContaining('Medical Crew');
      expect(
        armorerCrewText,
        findsWidgets,
        reason: 'Armorer Crew should be visible for superuser',
      );
      expect(
        medicalCrewText,
        findsWidgets,
        reason: 'Medical Crew should be visible for superuser',
      );

      // Event name should also appear (title of each ListTile)
      expect(
        find.text('E2E Test Event'),
        findsWidgets,
        reason: 'E2E Test Event name should be visible',
      );
      debugPrint('=== Both seed crews verified ===');

      // ====================================================================
      // STEP 4: Tap Armorer crew to see crew members
      // ====================================================================
      debugPrint('=== STEP 4: Open Armorer crew ===');
      print('>>> STEP 4: Tap Armorer crew');
      // Tap on the E2E Test Event / Armorer row
      final armorerItem = find.byKey(const ValueKey('select_crew_item_1'));
      if (armorerItem.evaluate().isNotEmpty) {
        await tester.tap(armorerItem);
      } else {
        // Fallback: tap on the E2E Test Event title in the Armorer row
        await tester.tap(find.text('E2E Test Event').first);
      }
      await _pumpForDuration(tester, const Duration(seconds: 3));

      // ====================================================================
      // STEP 5: Verify crew chief and existing member
      // ====================================================================
      debugPrint('=== STEP 5: Verify crew chief and member ===');
      print('>>> STEP 5: Verify crew chief and member');

      // Crew chief should be displayed in header
      final crewChiefText = find.text('Armorer One');
      expect(
        crewChiefText,
        findsWidgets,
        reason: 'Crew chief "Armorer One" should be visible',
      );

      // Seed member: Armorer Two
      final armorerTwoText = find.text('Armorer Two');
      expect(
        armorerTwoText,
        findsWidgets,
        reason: 'Crew member "Armorer Two" should be listed',
      );
      debugPrint('=== Crew chief and member verified ===');

      // ====================================================================
      // STEP 6: Add Referee One as a crew member via NameFinderDialog
      // ====================================================================
      debugPrint('=== STEP 6: Add Referee One to Armorer crew ===');
      print('>>> STEP 6: Add Referee One');
      final addMemberBtn = find.byKey(
        const ValueKey('manage_crew_add_member_button'),
      );
      expect(
        addMemberBtn,
        findsOneWidget,
        reason: 'Add member FAB should be visible',
      );
      await tester.tap(addMemberBtn);
      await _pumpForDuration(tester, const Duration(seconds: 2));

      // NameFinderDialog should be open
      await _searchAndSelectUser(tester, 'Referee', 'One');
      print('>>> STEP 6: Referee One added');

      // Wait for SnackBar + reload
      await _pumpForDuration(tester, const Duration(seconds: 3));

      // ====================================================================
      // STEP 7: Verify Referee One now appears in the member list
      // ====================================================================
      debugPrint('=== STEP 7: Verify Referee One in member list ===');
      print('>>> STEP 7: Verify Referee One in list');
      final refereeOneText = find.text('Referee One');
      expect(
        refereeOneText,
        findsWidgets,
        reason: 'Referee One should now be listed as crew member',
      );

      // Also verify Armorer Two is still there
      expect(
        find.text('Armorer Two'),
        findsWidgets,
        reason: 'Armorer Two should still be listed',
      );
      debugPrint('=== Referee One confirmed in list ===');

      // ====================================================================
      // STEP 8: Remove Referee One from crew
      // ====================================================================
      debugPrint('=== STEP 8: Remove Referee One from crew ===');
      print('>>> STEP 8: Remove Referee One');
      final removeRefereeBtn = find.byKey(
        ValueKey('manage_crew_remove_${TestConfig.testUsers.referee1.id}'),
      );
      if (removeRefereeBtn.evaluate().isNotEmpty) {
        await tester.tap(removeRefereeBtn);
      } else {
        // Fallback: find delete icon near Referee One
        debugPrint('WARNING: remove button by key not found, trying by icon');
        final deleteIcons = find.byIcon(Icons.delete);
        if (deleteIcons.evaluate().length > 1) {
          // Referee One should be the second member (Armorer Two first)
          await tester.tap(deleteIcons.last);
        }
      }
      await _pumpForDuration(tester, const Duration(seconds: 3));
      print('>>> STEP 8: Referee One removed');

      // ====================================================================
      // STEP 9: Verify Referee One is gone, Armorer Two still present
      // ====================================================================
      debugPrint('=== STEP 9: Verify Referee One removed ===');
      print('>>> STEP 9: Verify removal');
      // Referee One should no longer be in the crew members list.
      // Note: "Referee One" text might still exist in the SnackBar, so check
      // specifically within the members list.
      final membersList = find.byKey(
        const ValueKey('manage_crew_members_list'),
      );
      if (membersList.evaluate().isNotEmpty) {
        final refereeInList = find.descendant(
          of: membersList,
          matching: find.text('Referee One'),
        );
        expect(
          refereeInList,
          findsNothing,
          reason: 'Referee One should no longer be in crew members list',
        );
      }

      // Armorer Two should still be there
      expect(
        find.descendant(of: membersList, matching: find.text('Armorer Two')),
        findsOneWidget,
        reason: 'Armorer Two should still be listed',
      );
      debugPrint('=== Referee One removed, Armorer Two still present ===');

      // ====================================================================
      // STEP 10: Navigate back to select crew list
      // ====================================================================
      debugPrint('=== STEP 10: Navigate back to crew list ===');
      print('>>> STEP 10: Back to crew list');
      await _tapBackButton(tester);
      await _pumpForDuration(tester, const Duration(seconds: 2));

      // Verify we're back on the crew list
      expect(
        find.byKey(const ValueKey('select_crew_list')),
        findsOneWidget,
        reason: 'Should be back on select crew list',
      );
      debugPrint('=== Back on select crew list ===');

      // ====================================================================
      // STEP 11: Navigate back to Select Event and logout
      // ====================================================================
      debugPrint('=== STEP 11: Logout superuser ===');
      print('>>> STEP 11: Logout superuser');
      await _navigateToSelectEvent(tester);
      await _logout(tester);

      // ====================================================================
      // STEP 12: Login as Armorer One (crew chief)
      // ====================================================================
      debugPrint('=== STEP 12: Login as Armorer One ===');
      print('>>> STEP 12: Login as Armorer One');
      await _login(tester, TestConfig.testUsers.armorer1);

      // ====================================================================
      // STEP 13: Navigate to Manage Crews — should only see Armorer crew
      // ====================================================================
      debugPrint('=== STEP 13: Armorer One navigates to Manage Crews ===');
      print('>>> STEP 13: Navigate to Manage Crews as Armorer One');
      await tester.tap(find.byKey(const ValueKey('settings_menu_button')));
      await _pumpForDuration(tester, const Duration(seconds: 1));

      // Manage Crews should be visible (Armorer One is a crew chief)
      final manageCrewsMenuItem = find.byKey(
        const ValueKey('settings_menu_manage_crews'),
      );
      expect(
        manageCrewsMenuItem,
        findsOneWidget,
        reason: 'Armorer One (crew chief) should see Manage Crews menu item',
      );
      await tester.tap(manageCrewsMenuItem);
      await _pumpForDuration(tester, const Duration(seconds: 3));

      // ====================================================================
      // STEP 14: Verify only Armorer crew visible (not Medical)
      // ====================================================================
      debugPrint('=== STEP 14: Verify only Armorer crew visible ===');
      print('>>> STEP 14: Verify only Armorer crew visible');
      final crewListForChief = find.byKey(const ValueKey('select_crew_list'));
      expect(
        crewListForChief,
        findsOneWidget,
        reason: 'Crew list should be visible',
      );

      expect(
        find.textContaining('Armorer Crew'),
        findsWidgets,
        reason: 'Armorer Crew should be visible for its chief',
      );

      // Medical crew should NOT be visible
      expect(
        find.textContaining('Medical Crew'),
        findsNothing,
        reason: 'Medical Crew should NOT be visible for Armorer crew chief',
      );
      debugPrint('=== Only Armorer crew visible for crew chief ===');

      // ====================================================================
      // STEP 15: Tap Armorer crew, add Medical Two as member
      // ====================================================================
      debugPrint('=== STEP 15: Add Medical Two to Armorer crew ===');
      print('>>> STEP 15: Add Medical Two to Armorer crew');
      // Tap the only crew item
      final armorerItemForChief = find.byKey(
        const ValueKey('select_crew_item_1'),
      );
      if (armorerItemForChief.evaluate().isNotEmpty) {
        await tester.tap(armorerItemForChief);
      } else {
        await tester.tap(find.textContaining('Armorer Crew').first);
      }
      await _pumpForDuration(tester, const Duration(seconds: 3));

      // Add Medical Two
      final addMemberBtn2 = find.byKey(
        const ValueKey('manage_crew_add_member_button'),
      );
      await tester.tap(addMemberBtn2);
      await _pumpForDuration(tester, const Duration(seconds: 2));
      await _searchAndSelectUser(tester, 'Medical', 'Two');
      await _pumpForDuration(tester, const Duration(seconds: 3));
      print('>>> STEP 15: Medical Two added');

      // Verify Medical Two is in the list
      expect(
        find.text('Medical Two'),
        findsWidgets,
        reason: 'Medical Two should now be in Armorer crew',
      );

      // ====================================================================
      // STEP 16: Remove Medical Two from Armorer crew
      // ====================================================================
      debugPrint('=== STEP 16: Remove Medical Two from crew ===');
      print('>>> STEP 16: Remove Medical Two');
      final removeMedicalTwoBtn = find.byKey(
        ValueKey('manage_crew_remove_${TestConfig.testUsers.medical2.id}'),
      );
      if (removeMedicalTwoBtn.evaluate().isNotEmpty) {
        await tester.tap(removeMedicalTwoBtn);
      } else {
        debugPrint('WARNING: remove button by key not found for Medical Two');
        final deleteIcons = find.byIcon(Icons.delete);
        if (deleteIcons.evaluate().length > 1) {
          await tester.tap(deleteIcons.last);
        }
      }
      await _pumpForDuration(tester, const Duration(seconds: 3));

      // Verify Medical Two is gone
      final membersList2 = find.byKey(
        const ValueKey('manage_crew_members_list'),
      );
      if (membersList2.evaluate().isNotEmpty) {
        expect(
          find.descendant(of: membersList2, matching: find.text('Medical Two')),
          findsNothing,
          reason: 'Medical Two should be removed from Armorer crew',
        );
      }
      debugPrint('=== Medical Two removed ===');
      print('>>> STEP 16: Medical Two removed');

      // ====================================================================
      // STEP 17: Navigate back and logout
      // ====================================================================
      debugPrint('=== STEP 17: Logout Armorer One ===');
      print('>>> STEP 17: Logout Armorer One');
      await _tapBackButton(tester);
      await _pumpForDuration(tester, const Duration(seconds: 2));
      await _navigateToSelectEvent(tester);
      await _logout(tester);

      // ====================================================================
      // STEP 18: Login as Referee One (not a crew chief or superuser)
      // ====================================================================
      debugPrint('=== STEP 18: Login as Referee One ===');
      print('>>> STEP 18: Login as Referee One');
      await _login(tester, TestConfig.testUsers.referee1);

      // ====================================================================
      // STEP 19: Verify Manage Crews is NOT in settings menu
      // ====================================================================
      debugPrint('=== STEP 19: Verify no Manage Crews for regular user ===');
      print('>>> STEP 19: Verify no Manage Crews menu');
      await tester.tap(find.byKey(const ValueKey('settings_menu_button')));
      await _pumpForDuration(tester, const Duration(seconds: 1));

      final manageCrewsForRegular = find.byKey(
        const ValueKey('settings_menu_manage_crews'),
      );
      expect(
        manageCrewsForRegular,
        findsNothing,
        reason: 'Referee One (regular user) should NOT see Manage Crews',
      );

      // Also verify Manage Events is not visible (Referee One is not organizer)
      final manageEventsForRegular = find.byKey(
        const ValueKey('settings_menu_manage_events'),
      );
      expect(
        manageEventsForRegular,
        findsNothing,
        reason: 'Referee One should NOT see Manage Events',
      );
      debugPrint('=== Regular user correctly cannot access Manage Crews ===');

      // ====================================================================
      // STEP 20: Logout directly (menu is still open from Step 19)
      // ====================================================================
      debugPrint('=== STEP 20: Final logout ===');
      print('>>> STEP 20: Final logout');
      // Menu is already open from Step 19, just tap logout
      await tester.tap(find.byKey(const ValueKey('settings_menu_logout')));
      await _pumpForDuration(tester, const Duration(seconds: 2));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find
            .byKey(const ValueKey('login_email_field'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);

      debugPrint('=== ALL MANAGE CREWS TESTS COMPLETE ===');
      print('>>> ALL MANAGE CREWS TESTS COMPLETE');
    });
  });
}

// =============================================================================
// Helper Functions
// =============================================================================

Future<void> _login(WidgetTester tester, TestUser user) async {
  expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);
  await tester.enterText(
    find.byKey(const ValueKey('login_email_field')),
    user.email,
  );
  await tester.enterText(
    find.byKey(const ValueKey('login_password_field')),
    user.password,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('login_submit_button')));
  await tester.pumpAndSettle(const Duration(seconds: 3));
  expect(find.byKey(const ValueKey('select_event_list')), findsOneWidget);
}

Future<void> _logout(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('settings_menu_button')));
  await _pumpForDuration(tester, const Duration(seconds: 1));
  await tester.tap(find.byKey(const ValueKey('settings_menu_logout')));
  await _pumpForDuration(tester, const Duration(seconds: 2));
  // Wait for login page to appear
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byKey(const ValueKey('login_email_field')).evaluate().isNotEmpty) {
      break;
    }
  }
  expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);
}

Future<void> _navigateToSelectEvent(WidgetTester tester) async {
  print('>>> _navigateToSelectEvent: starting');
  for (int i = 0; i < 5; i++) {
    await _pumpForDuration(tester, const Duration(seconds: 1));

    // Check if already on select event page
    if (find.byKey(const ValueKey('select_event_list')).evaluate().isNotEmpty) {
      print(
        '>>> _navigateToSelectEvent: found select_event_list at iteration $i',
      );
      return;
    }

    // Look for any back button variant
    final backBtn = find.byTooltip('Back');
    final backBtn2 = find.byIcon(Icons.arrow_back);
    final backBtn3 = find.byIcon(Icons.arrow_back_ios);
    final backBtn4 = find.byIcon(Icons.arrow_back_ios_new);
    Finder? found;
    if (backBtn.evaluate().isNotEmpty) {
      found = backBtn;
    } else if (backBtn2.evaluate().isNotEmpty) {
      found = backBtn2;
    } else if (backBtn3.evaluate().isNotEmpty) {
      found = backBtn3;
    } else if (backBtn4.evaluate().isNotEmpty) {
      found = backBtn4;
    }

    if (found != null) {
      print('>>> _navigateToSelectEvent: tapping back at iteration $i');
      await tester.tap(found.first);
      await _pumpForDuration(tester, const Duration(seconds: 1));
    } else {
      print('>>> _navigateToSelectEvent: no back button at iteration $i');
      break;
    }
  }

  // Wait for event list to load
  for (int i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byKey(const ValueKey('select_event_list')).evaluate().isNotEmpty) {
      return;
    }
  }

  expect(
    find.byKey(const ValueKey('select_event_list')),
    findsOneWidget,
    reason: 'Should be on Select Event page with events loaded',
  );
}

Future<void> _searchAndSelectUser(
  WidgetTester tester,
  String firstName,
  String lastName,
) async {
  await _pumpForDuration(tester, const Duration(seconds: 1));

  final firstNameField = find.byKey(
    const ValueKey('name_finder_firstname_field'),
  );
  final lastNameField = find.byKey(
    const ValueKey('name_finder_lastname_field'),
  );

  debugPrint('_searchAndSelectUser: Looking for $firstName $lastName');

  if (firstNameField.evaluate().isNotEmpty) {
    await tester.enterText(firstNameField, firstName);
    await tester.enterText(lastNameField, lastName);
    await tester.pump(const Duration(milliseconds: 300));

    // Dismiss keyboard before tapping search
    FocusManager.instance.primaryFocus?.unfocus();
    await _pumpForDuration(tester, const Duration(seconds: 1));

    await tester.tap(find.byKey(const ValueKey('name_finder_search_button')));
    // Wait for search results
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.text('$firstName $lastName').evaluate().isNotEmpty) break;
    }

    final userText = find.text('$firstName $lastName');
    debugPrint(
      'User "$firstName $lastName" found: ${userText.evaluate().length}',
    );
    if (userText.evaluate().isNotEmpty) {
      await tester.tap(userText.first);
      // Wait for dialog to close and member to be saved
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    } else {
      debugPrint('WARNING: User $firstName $lastName not found');
    }
  } else {
    debugPrint('WARNING: name_finder_firstname_field not found');
  }
}

/// Tap the back button, handling iOS icon variants.
Future<void> _tapBackButton(WidgetTester tester) async {
  final backBtn = find.byTooltip('Back');
  final backBtn2 = find.byIcon(Icons.arrow_back);
  final backBtn3 = find.byIcon(Icons.arrow_back_ios);
  final backBtn4 = find.byIcon(Icons.arrow_back_ios_new);
  Finder? found;
  if (backBtn.evaluate().isNotEmpty) {
    found = backBtn;
  } else if (backBtn2.evaluate().isNotEmpty) {
    found = backBtn2;
  } else if (backBtn3.evaluate().isNotEmpty) {
    found = backBtn3;
  } else if (backBtn4.evaluate().isNotEmpty) {
    found = backBtn4;
  }
  if (found != null) {
    await tester.tap(found.first);
    await _pumpForDuration(tester, const Duration(seconds: 2));
  } else {
    print('>>> _tapBackButton: WARNING - no back button found');
  }
}

/// Pump frames for a total duration without using pumpAndSettle.
/// This avoids hanging on SnackBar or other persistent animations.
Future<void> _pumpForDuration(WidgetTester tester, Duration total) async {
  const interval = Duration(milliseconds: 200);
  final steps = total.inMilliseconds ~/ interval.inMilliseconds;
  for (int i = 0; i < steps; i++) {
    await tester.pump(interval);
  }
}
