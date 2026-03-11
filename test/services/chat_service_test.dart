import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/services/chat_service.dart';

void main() {
  group('ChatService.parseSmsMessage', () {
    late ChatService chatService;

    setUp(() {
      chatService = ChatService();
    });

    group('old format: [SMS from Name] message', () {
      test('parses name and message', () {
        final result = chatService.parseSmsMessage(
          '[SMS from John Doe] Help needed on strip 3',
        );
        expect(result.senderName, 'John Doe');
        expect(result.messageText, 'Help needed on strip 3');
      });

      test('parses phone number with formatting', () {
        final result = chatService.parseSmsMessage(
          '[SMS from (724) 612-2359] weapon issue',
        );
        // Phone number should have non-digit chars stripped
        expect(result.senderName, '7246122359');
        expect(result.messageText, 'weapon issue');
      });

      test('parses raw phone number', () {
        final result = chatService.parseSmsMessage(
          '[SMS from 5551234567] problem here',
        );
        expect(result.senderName, '5551234567');
        expect(result.messageText, 'problem here');
      });

      test('handles empty message after bracket', () {
        final result = chatService.parseSmsMessage(
          '[SMS from Bob]',
        );
        expect(result.senderName, 'Bob');
        expect(result.messageText, '');
      });

      test('handles message with extra whitespace', () {
        final result = chatService.parseSmsMessage(
          '[SMS from  Bob ]   hello world  ',
        );
        expect(result.senderName, 'Bob');
        expect(result.messageText, 'hello world');
      });
    });

    group('new format: Name: message', () {
      test('parses name and message', () {
        final result = chatService.parseSmsMessage('John Doe: Help me');
        expect(result.senderName, 'John Doe');
        expect(result.messageText, 'Help me');
      });

      test('handles single word name', () {
        final result = chatService.parseSmsMessage('Bob: On my way');
        expect(result.senderName, 'Bob');
        expect(result.messageText, 'On my way');
      });

      test('handles message with colons', () {
        final result = chatService.parseSmsMessage('Bob: Time is: 3:00 PM');
        expect(result.senderName, 'Bob');
        expect(result.messageText, 'Time is: 3:00 PM');
      });
    });

    group('fallback', () {
      test('returns SMS as sender for unrecognized format', () {
        final result = chatService.parseSmsMessage('Just a plain message');
        expect(result.senderName, 'SMS');
        expect(result.messageText, 'Just a plain message');
      });

      test('handles empty string', () {
        final result = chatService.parseSmsMessage('');
        expect(result.senderName, 'SMS');
        expect(result.messageText, '');
      });

      test('does not match colon at position 0', () {
        final result = chatService.parseSmsMessage(': no name');
        expect(result.senderName, 'SMS');
        expect(result.messageText, ': no name');
      });

      test('does not match colon too far into message (>50 chars)', () {
        final longPrefix = 'A' * 51;
        final result = chatService.parseSmsMessage('$longPrefix: message');
        expect(result.senderName, 'SMS');
      });
    });
  });
}
