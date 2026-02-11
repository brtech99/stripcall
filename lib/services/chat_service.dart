import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'notification_service.dart';
import '../utils/debug_utils.dart';

/// Service for handling problem chat operations.
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  /// Load messages for a problem, filtered by user access.
  Future<List<Map<String, dynamic>>> loadMessages({
    required int problemId,
    required String? currentUserId,
    required bool isCrewMember,
    required bool isSuperUser,
  }) async {
    try {
      final messages = await Supabase.instance.client
          .from('messages')
          .select('*')
          .eq('problem', problemId)
          .order('created_at', ascending: true);

      // Filter messages based on user access
      final filteredMessages = messages.where((msg) {
        if (isCrewMember || isSuperUser) {
          return true; // Crew members and superusers see all messages
        }
        // Non-crew members see messages marked for them OR messages they authored
        final includeReporter = msg['include_reporter'];
        final isAuthor = msg['author'] == currentUserId;
        return isAuthor || includeReporter == null || includeReporter == true;
      }).toList();

      return List<Map<String, dynamic>>.from(filteredMessages);
    } catch (e) {
      debugLogError('Error loading messages', e);
      rethrow;
    }
  }

  /// Load the display style for a crew.
  Future<String?> loadCrewDisplayStyle(int crewId) async {
    try {
      final response = await Supabase.instance.client
          .from('crews')
          .select('display_style')
          .eq('id', crewId)
          .maybeSingle();

      return response?['display_style'] as String?;
    } catch (e) {
      debugLogError('Error loading crew display style', e);
      return null;
    }
  }

  /// Get user's full name by ID.
  Future<String?> getUserName(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('firstname, lastname')
          .eq('supabase_id', userId)
          .maybeSingle();

      if (response != null) {
        final firstName = response['firstname'] as String? ?? '';
        final lastName = response['lastname'] as String? ?? '';
        final fullName = '$firstName $lastName'.trim();
        return fullName.isNotEmpty ? fullName : null;
      }
      return null;
    } catch (e) {
      debugLogError('Error loading user name', e);
      return null;
    }
  }

  /// Send a message to a problem chat.
  Future<void> sendMessage({
    required int problemId,
    required int crewId,
    required String authorId,
    required String message,
    required bool includeReporter,
    String? reporterId,
  }) async {
    final now = DateTime.now().toUtc();
    final insertData = {
      'problem': problemId,
      'crew': crewId,
      'author': authorId,
      'message': message,
      'created_at': now.toIso8601String(),
      'include_reporter': includeReporter,
    };

    await Supabase.instance.client.from('messages').insert(insertData);

    // Send push notification (fire and forget)
    _sendPushNotification(
      problemId: problemId,
      crewId: crewId,
      senderId: authorId,
      message: message,
      includeReporter: includeReporter,
      reporterId: reporterId,
    );

    // Send SMS notification (fire and forget)
    _sendSmsNotification(
      problemId: problemId,
      senderId: authorId,
      message: message,
      includeReporter: includeReporter,
    );
  }

  Future<void> _sendPushNotification({
    required int problemId,
    required int crewId,
    required String senderId,
    required String message,
    required bool includeReporter,
    String? reporterId,
  }) async {
    try {
      await NotificationService().sendCrewNotification(
        title: 'New Message',
        body: message.length > 50 ? '${message.substring(0, 50)}...' : message,
        crewId: crewId.toString(),
        senderId: senderId,
        data: {
          'type': 'new_message',
          'problemId': problemId.toString(),
          'crewId': crewId.toString(),
        },
        includeReporter: includeReporter,
        reporterId: reporterId,
      );
    } catch (e) {
      debugLogError('Error sending push notification', e);
    }
  }

  Future<void> _sendSmsNotification({
    required int problemId,
    required String senderId,
    required String message,
    required bool includeReporter,
  }) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      // Get sender's name
      final senderName = await getUserName(senderId) ?? 'Crew';

      const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
      const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
      final url = Uri.parse('$supabaseUrl/functions/v1/send-sms');

      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': supabaseAnonKey,
        },
        body: jsonEncode({
          'problemId': problemId,
          'message': message,
          'type': 'message',
          'senderName': senderName,
          'includeReporter': includeReporter,
        }),
      );
    } catch (e) {
      debugLogError('Error sending SMS notification', e);
    }
  }

  /// Parse SMS message format to extract sender name and message text.
  /// Returns (senderName, messageText).
  ({String senderName, String messageText}) parseSmsMessage(String rawMessage) {
    // Try old format: "[SMS from Name] message" or "[SMS from (724) 612-2359] message"
    final oldFormatMatch = RegExp(
      r'^\[SMS from ([^\]]+)\]\s*(.*)$',
    ).firstMatch(rawMessage);

    if (oldFormatMatch != null) {
      var smsName = oldFormatMatch.group(1)!.trim();
      final smsText = oldFormatMatch.group(2)!.trim();
      // Clean up phone number format - remove parentheses, dashes, spaces
      if (smsName.contains('(') || smsName.contains('-')) {
        smsName = smsName.replaceAll(RegExp(r'[^\d]'), '');
      }
      return (senderName: smsName, messageText: smsText);
    }

    // Try new format: "Name: message"
    final colonIndex = rawMessage.indexOf(': ');
    if (colonIndex > 0 && colonIndex < 50) {
      return (
        senderName: rawMessage.substring(0, colonIndex),
        messageText: rawMessage.substring(colonIndex + 2),
      );
    }

    // Fallback: return as-is
    return (senderName: 'SMS', messageText: rawMessage);
  }
}
