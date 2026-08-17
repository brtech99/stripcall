import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/problem_notification.dart';
import '../theme/theme.dart';

class NotificationCard extends StatelessWidget {
  final ProblemNotification notification;
  final VoidCallback onAcknowledge;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onAcknowledge,
  });

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final withdrawal = notification.withdrawal;
    final isApple = AppTheme.isApplePlatform(context);
    final accentColor = Colors.orange.shade700;

    return Card(
      key: ValueKey('notification_card_${notification.id}'),
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLg,
        side: BorderSide(color: accentColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + title
            Row(
              children: [
                Icon(
                  isApple ? CupertinoIcons.exclamationmark_triangle_fill : Icons.warning_amber_rounded,
                  color: accentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Medical Withdrawal${withdrawal != null ? ' — ${withdrawal.fencerName}' : ''}',
                    style: AppTypography.problemTitle(context).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Details
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (withdrawal != null) ...[
                    _buildDetailRow(context, 'Membership #', withdrawal.membershipNumber),
                    const SizedBox(height: 4),
                    _buildDetailRow(context, 'Event', withdrawal.eventName),
                    const SizedBox(height: 4),
                  ],
                  if (notification.strip != null) ...[
                    _buildDetailRow(context, 'Strip', notification.strip!),
                    const SizedBox(height: 4),
                  ],
                  if (notification.approverName != null) ...[
                    _buildDetailRow(
                      context,
                      'Approved by',
                      '${notification.approverName}${notification.approvedAt != null ? ' at ${_formatTime(notification.approvedAt!)}' : ''}',
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (withdrawal?.notes != null && withdrawal!.notes!.isNotEmpty) ...[
                    _buildDetailRow(context, 'Notes', withdrawal.notes!),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Acknowledge button
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: _buildAcknowledgeButton(context, isApple, accentColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: AppTypography.bodySmall(context).copyWith(
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySmall(context),
          ),
        ),
      ],
    );
  }

  Widget _buildAcknowledgeButton(BuildContext context, bool isApple, Color color) {
    final borderRadius = BorderRadius.circular(20);
    if (isApple) {
      return CupertinoButton(
        key: ValueKey('notification_acknowledge_button_${notification.id}'),
        onPressed: onAcknowledge,
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        minimumSize: Size.zero,
        borderRadius: borderRadius,
        child: const Text(
          'Acknowledge',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return ElevatedButton(
      key: ValueKey('notification_acknowledge_button_${notification.id}'),
      onPressed: onAcknowledge,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: const Text('Acknowledge'),
    );
  }
}
