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

  String _formatTime() {
    final local = createdAt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender name + timestamp
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : AppSpacing.xs,
              right: isMe ? AppSpacing.xs : 0,
              bottom: 2,
            ),
            child: Text(
              isMe
                  ? _formatTime()
                  : '${_formatSenderName(senderName)} \u00B7 ${_formatTime()}',
              style: AppTypography.bodySmall(context).copyWith(
                color: AppColors.textSecondary(context),
                fontSize: 11,
              ),
            ),
          ),
          // Bubble
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              padding: EdgeInsets.all(AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.chatBubbleSelf(context).withValues(alpha: 0.2)
                    : AppColors.chatBubbleOther(context),
                borderRadius: AppSpacing.borderRadiusMd,
              ),
              child: Text(
                text,
                style: AppTypography.chatMessage(context).copyWith(
                  color: isMe
                      ? AppColors.textPrimary(context)
                      : AppColors.chatBubbleOtherText(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
