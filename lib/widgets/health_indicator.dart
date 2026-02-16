import 'package:flutter/material.dart';
import '../services/supabase_manager.dart';

/// Small status dot that shows the health of the dual Supabase backends.
///
/// - Green: both instances healthy
/// - Yellow: one instance down (failover mode)
/// - Red: both instances down
///
/// Only visible when a secondary instance is configured.
class HealthIndicator extends StatelessWidget {
  const HealthIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final sm = SupabaseManager();
    if (!sm.hasSecondary) return const SizedBox.shrink();

    return ValueListenableBuilder<HealthStatus>(
      valueListenable: sm.healthStatus,
      builder: (context, status, _) {
        final (color, tooltip) = switch (status) {
          HealthStatus.allHealthy => (Colors.green, 'All systems operational'),
          HealthStatus.degraded => (
            Colors.orange,
            'Failover mode — one backend is down',
          ),
          HealthStatus.allDown => (Colors.red, 'Both backends unreachable'),
        };

        return Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        );
      },
    );
  }
}
