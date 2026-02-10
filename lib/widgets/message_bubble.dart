import 'package:flutter/material.dart';
import '../theme/theme.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final String senderName;
  final bool isMe;
  final DateTime createdAt;
  final String? displayStyle;

  const MessageBubble({
    super.key,
    required this.text,
    required this.senderName,
    required this.isMe,
    required this.createdAt,
    this.displayStyle,
  });

  String _formatSenderName(String fullName) {
    if (displayStyle == 'firstInitial-Last') {
      final parts = fullName.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1]}';
      }
    }
    return fullName;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          final timeString =
              '${createdAt.toLocal().hour.toString().padLeft(2, '0')}:${createdAt.toLocal().minute.toString().padLeft(2, '0')}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sent at $timeString'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 2, horizontal: AppSpacing.xs),
          padding: EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.chatBubbleSelf(context).withValues(alpha: 0.2)
                : AppColors.chatBubbleOther(context),
            borderRadius: AppSpacing.borderRadiusMd,
          ),
          child: Text(
            isMe ? text : '${_formatSenderName(senderName)}: $text',
            style: AppTypography.chatMessage(context).copyWith(
              color: isMe
                  ? AppColors.textPrimary(context)
                  : AppColors.chatBubbleOtherText(context),
            ),
          ),
        ),
      ),
    );
  }
}
