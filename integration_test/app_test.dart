import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';
import 'package:stripcall/main.dart' as app;

import 'test_config.dart';

void main() {
  patrolTest(
    'Login and logout flow',
    ($) async {
      // Start the app
      app.main();
      await $.pumpAndSettle();

      // Wait for login page
      await $(const ValueKey('login_email_field')).waitUntilVisible();

      // Login as referee1
      await $(const ValueKey('login_email_field')).enterText(TestConfig.testUsers.referee1.email);
      await $(const ValueKey('login_password_field')).enterText(TestConfig.testUsers.referee1.password);
      await $(const ValueKey('login_submit_button')).tap();
      await $.pumpAndSettle();

      // Verify we're on the select event page
      await $(const ValueKey('select_event_list')).waitUntilVisible();

      // Logout
      await $(const ValueKey('settings_menu_button')).tap();
      await $(const ValueKey('settings_menu_logout')).waitUntilVisible();
      await $(const ValueKey('settings_menu_logout')).tap();
      await $.pumpAndSettle();

      // Verify we're back on login page
      await $(const ValueKey('login_email_field')).waitUntilVisible();
    },
  );
}
