import 'dart:convert';
import 'package:http/http.dart' as http;
import '../test_config.dart';

/// Simulated phone numbers for E2E testing.
/// These correspond to the 5 phones in the SMS simulator.
///
/// Phone-to-user mapping (from seed.sql):
/// - phone1 (2025551001) -> Armorer One (armorer1, crew chief)
/// - phone2 (2025551002) -> Armorer Two (armorer2, crew member)
/// - phone3 (2025551003) -> Medical One (medical1, crew chief)
/// - phone4 (2025551004) -> Medical Two (medical2, crew member)
/// - phone5 (2025551005) -> RESERVED for dynamically created users
enum SimPhone {
  phone1('2025551001'),
  phone2('2025551002'),
  phone3('2025551003'),
  phone4('2025551004'),
  phone5('2025551005');

  final String number;
  const SimPhone(this.number);

  /// Get SimPhone from a phone number string
  static SimPhone? fromNumber(String? phone) {
    if (phone == null) return null;
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    for (final p in SimPhone.values) {
      if (p.number == normalized) return p;
    }
    return null;
  }
}

/// Crew Twilio phone numbers for routing SMS messages.
enum CrewNumber {
  armorer('+17542276679'),
  medical('+13127577223'),
  natloff('+16504803067');

  final String number;
  const CrewNumber(this.number);
}

/// Represents an SMS message in the simulator.
class SimulatorMessage {
  final String phone;
  final String direction; // 'inbound' or 'outbound'
  final String twilioNumber;
  final String message;
  final DateTime createdAt;

  SimulatorMessage({
    required this.phone,
    required this.direction,
    required this.twilioNumber,
    required this.message,
    required this.createdAt,
  });

  factory SimulatorMessage.fromJson(Map<String, dynamic> json) {
    return SimulatorMessage(
      phone: json['phone'] as String,
      direction: json['direction'] as String,
      twilioNumber: json['twilio_number'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isInbound => direction == 'inbound';
  bool get isOutbound => direction == 'outbound';
}

/// Helper class for E2E tests to simulate SMS interactions.
///
/// This allows tests to:
/// - Send SMS messages as simulated reporters
/// - Receive responses from crew members
/// - Query message history for verification
///
/// Example usage:
/// ```dart
/// final simulator = SmsSimulator();
///
/// // Reporter sends a problem
/// final reply = await simulator.sendSms(
///   from: SimPhone.phone1,
///   to: CrewNumber.armorer,
///   message: 'Broken blade on strip 4',
/// );
///
/// // Check what messages the phone has received
/// final messages = await simulator.getMessages(SimPhone.phone1);
/// ```
class SmsSimulator {
  final String _supabaseUrl;
  final String _anonKey;
  final http.Client _client;

  SmsSimulator({
    String? supabaseUrl,
    String? anonKey,
    http.Client? client,
  })  : _supabaseUrl = supabaseUrl ?? TestConfig.supabaseUrl,
        _anonKey = anonKey ?? TestConfig.supabaseAnonKey,
        _client = client ?? http.Client();

  /// Send an SMS from a simulated phone to a crew number.
  ///
  /// Returns the automatic reply message if one was generated,
  /// or null if no reply was sent.
  ///
  /// Example:
  /// ```dart
  /// final reply = await simulator.sendSms(
  ///   from: SimPhone.phone1,
  ///   to: CrewNumber.armorer,
  ///   message: 'Equipment problem on strip 4',
  /// );
  /// print(reply); // "Problem reported. You are caller +1. Updates will be sent to this number."
  /// ```
  Future<String?> sendSms({
    required SimPhone from,
    required CrewNumber to,
    required String message,
  }) async {
    return _sendSmsInternal(from: from.number, to: to.number, message: message);
  }

  /// Send an SMS as a TestUser to a crew.
  ///
  /// This is a convenience method that uses the user's simulator phone number.
  /// Throws if the user doesn't have a simulator phone number.
  ///
  /// Example:
  /// ```dart
  /// // Armorer2 sends SMS to their own crew (as if texting from outside the app)
  /// final reply = await simulator.sendSmsAsUser(
  ///   user: TestConfig.testUsers.armorer2,
  ///   to: CrewNumber.armorer,
  ///   message: 'On my way to strip 5',
  /// );
  /// ```
  Future<String?> sendSmsAsUser({
    required TestUser user,
    required CrewNumber to,
    required String message,
  }) async {
    if (user.phone == null) {
      throw ArgumentError('User ${user.fullName} does not have a phone number');
    }
    if (!user.hasSimPhone) {
      throw ArgumentError('User ${user.fullName} phone ${user.phone} is not a simulator phone');
    }
    return _sendSmsInternal(from: user.phone!, to: to.number, message: message);
  }

  Future<String?> _sendSmsInternal({
    required String from,
    required String to,
    required String message,
  }) async {
    final response = await _client.post(
      Uri.parse('$_supabaseUrl/functions/v1/simulator-send-sms'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': _anonKey,
      },
      body: jsonEncode({
        'from': from,
        'to': to,
        'body': message,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to send simulated SMS: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['reply'] as String?;
  }

  /// Get all messages for a simulated phone.
  ///
  /// Returns messages ordered by creation time (oldest first).
  /// Use [direction] to filter by 'inbound' or 'outbound'.
  Future<List<SimulatorMessage>> getMessages(
    SimPhone phone, {
    String? direction,
  }) async {
    var query = 'phone=eq.${phone.number}&order=created_at.asc';
    if (direction != null) {
      query += '&direction=eq.$direction';
    }

    final response = await _client.get(
      Uri.parse('$_supabaseUrl/rest/v1/sms_simulator?$query'),
      headers: {
        'apikey': _anonKey,
        'Authorization': 'Bearer $_anonKey',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get simulator messages: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((json) => SimulatorMessage.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get only inbound messages (responses from crew) for a phone.
  Future<List<SimulatorMessage>> getInboundMessages(SimPhone phone) {
    return getMessages(phone, direction: 'inbound');
  }

  /// Get only outbound messages (sent by the simulated phone).
  Future<List<SimulatorMessage>> getOutboundMessages(SimPhone phone) {
    return getMessages(phone, direction: 'outbound');
  }

  /// Clear all messages for a simulated phone.
  /// Useful for test setup/teardown.
  Future<void> clearMessages(SimPhone phone) async {
    final response = await _client.delete(
      Uri.parse('$_supabaseUrl/rest/v1/sms_simulator?phone=eq.${phone.number}'),
      headers: {
        'apikey': _anonKey,
        'Authorization': 'Bearer $_anonKey',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        'Failed to clear simulator messages: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Clear all messages for all simulated phones.
  /// Useful for test setup/teardown.
  Future<void> clearAllMessages() async {
    for (final phone in SimPhone.values) {
      await clearMessages(phone);
    }
  }

  /// Wait for an inbound message matching the predicate.
  ///
  /// Polls the simulator until a matching message is found or timeout.
  /// Useful for waiting for crew responses.
  ///
  /// Example:
  /// ```dart
  /// // Wait for crew to respond
  /// final response = await simulator.waitForInboundMessage(
  ///   SimPhone.phone1,
  ///   matcher: (msg) => msg.message.contains('On my way'),
  ///   timeout: Duration(seconds: 10),
  /// );
  /// ```
  Future<SimulatorMessage?> waitForInboundMessage(
    SimPhone phone, {
    bool Function(SimulatorMessage)? matcher,
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(milliseconds: 500),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      final messages = await getInboundMessages(phone);

      if (messages.isNotEmpty) {
        if (matcher == null) {
          return messages.last;
        }

        for (final msg in messages.reversed) {
          if (matcher(msg)) {
            return msg;
          }
        }
      }

      await Future.delayed(pollInterval);
    }

    return null; // Timeout reached
  }

  /// Dispose of resources.
  void dispose() {
    _client.close();
  }
}
