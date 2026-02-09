import 'dart:convert';
import 'package:http/http.dart' as http;

/// Helper class for retrieving emails from Mailpit during E2E tests.
///
/// Mailpit is the local email server that Supabase uses for development.
/// It captures all emails sent by Supabase Auth (confirmation, password reset, etc.)
///
/// Mailpit UI: http://127.0.0.1:54324
/// Mailpit API: http://127.0.0.1:54324/api/v1/
///
/// Example usage:
/// ```dart
/// final mailpit = MailpitHelper();
///
/// // Create account (triggers confirmation email)
/// await supabase.auth.signUp(email: 'test@example.com', password: 'password');
///
/// // Get the confirmation link from the email
/// final link = await mailpit.getConfirmationLink('test@example.com');
///
/// // Navigate to link or extract token
/// ```
class MailpitHelper {
  final String _baseUrl;
  final http.Client _client;

  MailpitHelper({
    String? baseUrl,
    http.Client? client,
  })  : _baseUrl = baseUrl ?? 'http://127.0.0.1:54324',
        _client = client ?? http.Client();

  /// Get all messages from Mailpit
  Future<List<MailpitMessage>> getMessages() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/messages'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get messages: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final messages = data['messages'] as List<dynamic>;

    return messages
        .map((m) => MailpitMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  /// Get messages for a specific email address
  Future<List<MailpitMessage>> getMessagesForEmail(String email) async {
    final allMessages = await getMessages();
    return allMessages.where((m) =>
      m.to.any((addr) => addr.toLowerCase() == email.toLowerCase())
    ).toList();
  }

  /// Wait for a message to arrive for the given email address
  Future<MailpitMessage?> waitForMessage(
    String email, {
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(milliseconds: 500),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      final messages = await getMessagesForEmail(email);
      if (messages.isNotEmpty) {
        // Return the most recent message
        messages.sort((a, b) => b.created.compareTo(a.created));
        return messages.first;
      }
      await Future.delayed(pollInterval);
    }

    return null;
  }

  /// Get the full message content including body
  Future<MailpitMessageDetail> getMessageDetail(String messageId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/message/$messageId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get message detail: ${response.statusCode}');
    }

    return MailpitMessageDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Extract confirmation link from a Supabase confirmation email
  ///
  /// Supabase confirmation emails contain a link like:
  /// http://127.0.0.1:54321/auth/v1/verify?token=...&type=signup&redirect_to=...
  Future<String?> getConfirmationLink(
    String email, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final message = await waitForMessage(email, timeout: timeout);
    if (message == null) return null;

    final detail = await getMessageDetail(message.id);

    // Look for confirmation link in HTML body
    final htmlBody = detail.html;
    if (htmlBody != null) {
      // Supabase uses a link with /auth/v1/verify or similar
      final linkRegex = RegExp(
        r'href="(https?://[^"]*(?:verify|confirm)[^"]*)"',
        caseSensitive: false,
      );
      final match = linkRegex.firstMatch(htmlBody);
      if (match != null) {
        return match.group(1);
      }
    }

    // Fallback: look in text body
    final textBody = detail.text;
    if (textBody != null) {
      final urlRegex = RegExp(
        r'(https?://[^\s]*(?:verify|confirm)[^\s]*)',
        caseSensitive: false,
      );
      final match = urlRegex.firstMatch(textBody);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Extract OTP code from a Supabase email (for OTP-based confirmation)
  Future<String?> getOtpCode(
    String email, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final message = await waitForMessage(email, timeout: timeout);
    if (message == null) return null;

    final detail = await getMessageDetail(message.id);

    // Look for 6-digit OTP code
    final body = detail.text ?? detail.html ?? '';
    final otpRegex = RegExp(r'\b(\d{6})\b');
    final match = otpRegex.firstMatch(body);

    return match?.group(1);
  }

  /// Delete all messages (useful for test cleanup)
  Future<void> deleteAllMessages() async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/v1/messages'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete messages: ${response.statusCode}');
    }
  }

  /// Delete messages for a specific email address
  Future<void> deleteMessagesForEmail(String email) async {
    final messages = await getMessagesForEmail(email);
    for (final message in messages) {
      await _client.delete(
        Uri.parse('$_baseUrl/api/v1/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'IDs': [message.id]}),
      );
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Summary of a Mailpit message (from list endpoint)
class MailpitMessage {
  final String id;
  final List<String> to;
  final String from;
  final String subject;
  final DateTime created;

  MailpitMessage({
    required this.id,
    required this.to,
    required this.from,
    required this.subject,
    required this.created,
  });

  factory MailpitMessage.fromJson(Map<String, dynamic> json) {
    final toList = (json['To'] as List<dynamic>?)
        ?.map((t) => (t as Map<String, dynamic>)['Address'] as String)
        .toList() ?? [];

    return MailpitMessage(
      id: json['ID'] as String,
      to: toList,
      from: (json['From'] as Map<String, dynamic>?)?['Address'] as String? ?? '',
      subject: json['Subject'] as String? ?? '',
      created: DateTime.parse(json['Created'] as String),
    );
  }
}

/// Full message detail (from single message endpoint)
class MailpitMessageDetail {
  final String id;
  final String? text;
  final String? html;
  final String subject;
  final List<String> to;
  final String from;

  MailpitMessageDetail({
    required this.id,
    this.text,
    this.html,
    required this.subject,
    required this.to,
    required this.from,
  });

  factory MailpitMessageDetail.fromJson(Map<String, dynamic> json) {
    final toList = (json['To'] as List<dynamic>?)
        ?.map((t) => (t as Map<String, dynamic>)['Address'] as String)
        .toList() ?? [];

    return MailpitMessageDetail(
      id: json['ID'] as String,
      text: json['Text'] as String?,
      html: json['HTML'] as String?,
      subject: json['Subject'] as String? ?? '',
      to: toList,
      from: (json['From'] as Map<String, dynamic>?)?['Address'] as String? ?? '',
    );
  }
}
