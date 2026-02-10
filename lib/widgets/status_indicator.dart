import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// A colored circle indicator for problem status.
///
/// Uses semantic colors from AppColors for consistent styling.
class StatusIndicator extends StatelessWidget {
  final String status;
  final double size;

  const StatusIndicator({
    super.key,
    required this.status,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (status) {
      case 'new':
        color = AppColors.statusError;
        break;
      case 'en_route':
        color = AppColors.statusWarning;
        break;
      case 'resolved':
        color = AppColors.statusSuccess;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
