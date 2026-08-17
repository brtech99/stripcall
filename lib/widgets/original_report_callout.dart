import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Read-only callout that shows the reporter's original message (the first
/// message on a problem) so a crew member can see it while triaging/editing
/// without dismissing the dialog. Renders nothing when [text] is null/blank.
class OriginalReportCallout extends StatelessWidget {
  final String? text;

  const OriginalReportCallout({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final value = text?.trim() ?? '';
    if (value.isEmpty) return const SizedBox.shrink();

    return Container(
      key: const ValueKey('original_report_callout'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Original Report',
            style: AppTypography.bodySmall(context).copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: SelectableText(
                value,
                style: AppTypography.bodyMedium(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
