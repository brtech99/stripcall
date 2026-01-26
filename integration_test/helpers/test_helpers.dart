import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';

import '../test_config.dart';

/// Helper function to login with a test user
Future<void> login(PatrolIntegrationTester $, TestUser user) async {
  await $(const ValueKey('login_email_field')).waitUntilVisible();
  await $(const ValueKey('login_email_field')).enterText(user.email);
  await $(const ValueKey('login_password_field')).enterText(user.password);
  await $(const ValueKey('login_submit_button')).tap();
  await $.pumpAndSettle();

  // Wait for navigation away from login - use select_event_list as indicator
  await $(const ValueKey('select_event_list')).waitUntilVisible();
}

/// Helper function to logout
Future<void> logout(PatrolIntegrationTester $) async {
  await $(const ValueKey('settings_menu_button')).tap();
  await $(const ValueKey('settings_menu_logout')).waitUntilVisible();
  await $(const ValueKey('settings_menu_logout')).tap();
  await $.pumpAndSettle();

  // Wait for login page
  await $(const ValueKey('login_email_field')).waitUntilVisible();
}

/// Navigate to settings menu item
Future<void> openSettingsMenuItem(PatrolIntegrationTester $, ValueKey itemKey) async {
  await $(const ValueKey('settings_menu_button')).tap();
  await $(itemKey).waitUntilVisible();
  await $(itemKey).tap();
  await $.pumpAndSettle();
}

/// Select an event from the event list
Future<void> selectEvent(PatrolIntegrationTester $, String eventName) async {
  await $(const ValueKey('select_event_list')).waitUntilVisible();
  await $(Text(eventName)).tap();
  await $.pumpAndSettle();
}

/// Search and select a user in the name finder dialog
Future<void> searchAndSelectUser(PatrolIntegrationTester $, String firstName, String lastName) async {
  await $(const ValueKey('name_finder_dialog')).waitUntilVisible();
  await $(const ValueKey('name_finder_firstname_field')).enterText(firstName);
  await $(const ValueKey('name_finder_lastname_field')).enterText(lastName);
  await $(const ValueKey('name_finder_search_button')).tap();
  await $.pumpAndSettle();

  // Select the user from results
  await $(Text('$firstName $lastName')).tap();
  await $.pumpAndSettle();
}
