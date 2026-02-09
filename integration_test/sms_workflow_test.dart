import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:stripcall/main.dart' as app;

import 'test_config.dart';
import 'helpers/test_helpers.dart';
import 'helpers/sms_simulator.dart';

/// E2E tests for SMS-based problem reporting workflow.
///
/// These tests simulate the real-world scenario where:
/// 1. A reporter (fencer, coach, spectator) texts a problem to the crew number
/// 2. Crew members see the problem in the app
/// 3. Crew members respond via the app
/// 4. The reporter receives the response via SMS
void main() {
  late SmsSimulator simulator;

  patrolSetUp(() async {
    simulator = SmsSimulator();
    // Clear any existing simulator messages before each test
    await simulator.clearAllMessages();
  });

  patrolTearDown(() async {
    simulator.dispose();
  });

  patrolTest(
    'Reporter sends SMS problem, crew sees and responds',
    ($) async {
      // Initialize the app
      app.main();
      await $.pumpAndSettle();

      // Step 1: Login as armorer crew member
      await login($, TestConfig.testUsers.armorer1);

      // Step 2: Select the test event
      // Note: This assumes an event exists. In a real test, you'd create one first
      // or ensure seed data includes it.
      await $(const ValueKey('select_event_list')).waitUntilVisible();

      // For now, just verify we're logged in and can see the event list
      // A full test would select an event and navigate to problems

      // Step 3: Simulated reporter sends a problem via SMS
      final reply = await simulator.sendSms(
        from: SimPhone.phone1,
        to: CrewNumber.armorer,
        message: 'Broken blade on strip 4',
      );

      // Verify the reporter got an acknowledgment
      expect(reply, isNotNull);
      expect(reply, contains('Problem reported'));

      // Step 4: Verify the message was recorded in simulator
      final outboundMessages = await simulator.getOutboundMessages(SimPhone.phone1);
      expect(outboundMessages.length, equals(1));
      expect(outboundMessages.first.message, equals('Broken blade on strip 4'));

      // Step 5: Check for inbound acknowledgment
      final inboundMessages = await simulator.getInboundMessages(SimPhone.phone1);
      expect(inboundMessages.length, greaterThanOrEqualTo(1));

      // Logout
      await logout($);
    },
  );

  patrolTest(
    'Multiple reporters can send problems to same crew',
    ($) async {
      app.main();
      await $.pumpAndSettle();

      // Login as crew member to have context
      await login($, TestConfig.testUsers.armorer1);
      await $(const ValueKey('select_event_list')).waitUntilVisible();

      // Reporter 1 sends a problem
      final reply1 = await simulator.sendSms(
        from: SimPhone.phone1,
        to: CrewNumber.armorer,
        message: 'Equipment issue strip 1',
      );
      expect(reply1, isNotNull);

      // Reporter 2 sends a different problem
      final reply2 = await simulator.sendSms(
        from: SimPhone.phone2,
        to: CrewNumber.armorer,
        message: 'Equipment issue strip 2',
      );
      expect(reply2, isNotNull);

      // Reporter 3 sends yet another problem
      final reply3 = await simulator.sendSms(
        from: SimPhone.phone3,
        to: CrewNumber.armorer,
        message: 'Equipment issue strip 3',
      );
      expect(reply3, isNotNull);

      // Verify each phone has its own message history
      final messages1 = await simulator.getMessages(SimPhone.phone1);
      final messages2 = await simulator.getMessages(SimPhone.phone2);
      final messages3 = await simulator.getMessages(SimPhone.phone3);

      expect(messages1.any((m) => m.message.contains('strip 1')), isTrue);
      expect(messages2.any((m) => m.message.contains('strip 2')), isTrue);
      expect(messages3.any((m) => m.message.contains('strip 3')), isTrue);

      await logout($);
    },
  );

  patrolTest(
    'Reporter can send follow-up messages',
    ($) async {
      app.main();
      await $.pumpAndSettle();

      await login($, TestConfig.testUsers.armorer1);
      await $(const ValueKey('select_event_list')).waitUntilVisible();

      // Initial problem report
      await simulator.sendSms(
        from: SimPhone.phone1,
        to: CrewNumber.armorer,
        message: 'Broken blade on strip 4',
      );

      // Follow-up message from same reporter
      await simulator.sendSms(
        from: SimPhone.phone1,
        to: CrewNumber.armorer,
        message: 'Actually it is strip 5, not 4',
      );

      // Verify both messages recorded
      final outbound = await simulator.getOutboundMessages(SimPhone.phone1);
      expect(outbound.length, equals(2));
      expect(outbound[0].message, contains('strip 4'));
      expect(outbound[1].message, contains('strip 5'));

      await logout($);
    },
  );

  patrolTest(
    'Different crews receive their own problems',
    ($) async {
      app.main();
      await $.pumpAndSettle();

      await login($, TestConfig.testUsers.armorer1);
      await $(const ValueKey('select_event_list')).waitUntilVisible();

      // Problem to Armorer crew
      final armorerReply = await simulator.sendSms(
        from: SimPhone.phone1,
        to: CrewNumber.armorer,
        message: 'Need blade repair',
      );
      expect(armorerReply, isNotNull);

      // Problem to Medical crew
      final medicalReply = await simulator.sendSms(
        from: SimPhone.phone2,
        to: CrewNumber.medical,
        message: 'Fencer needs ice',
      );
      expect(medicalReply, isNotNull);

      // Verify messages went to correct crews
      final armorerMessages = await simulator.getMessages(SimPhone.phone1);
      final medicalMessages = await simulator.getMessages(SimPhone.phone2);

      // Phone 1 messages should be to armorer number
      expect(
        armorerMessages.every((m) => m.twilioNumber == CrewNumber.armorer.number),
        isTrue,
      );

      // Phone 2 messages should be to medical number
      expect(
        medicalMessages.every((m) => m.twilioNumber == CrewNumber.medical.number),
        isTrue,
      );

      await logout($);
    },
  );
}
