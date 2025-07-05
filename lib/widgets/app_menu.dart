import 'package:flutter/material.dart';

class AppMenu extends StatelessWidget {
  final bool showManageEvents;
  
  const AppMenu({
    super.key,
    this.showManageEvents = false,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          // Add menu items here as needed
        ],
      ),
    );
  }
} 