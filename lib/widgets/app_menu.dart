import 'package:flutter/material.dart';
import '../theme/theme.dart';

class AppMenu extends StatelessWidget {
  final bool showManageEvents;

  const AppMenu({super.key, this.showManageEvents = false});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(color: AppColors.primary(context)),
            child: Text(
              'Menu',
              style: AppTypography.headlineSmall(
                context,
              ).copyWith(color: AppColors.onPrimary(context)),
            ),
          ),
          // Add menu items here as needed
        ],
      ),
    );
  }
}
