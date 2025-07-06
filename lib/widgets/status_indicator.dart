import 'package:flutter/material.dart';

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
    Color color;
    switch (status) {
      case 'new':
        color = Colors.red;
        break;
      case 'en_route':
        color = Colors.orange;
        break;
      case 'resolved':
        color = Colors.green;
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