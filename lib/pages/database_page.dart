import 'package:flutter/material.dart';
import 'manage_symptoms_page.dart';
import 'user_management_page.dart';

class DatabasePage extends StatelessWidget {
  const DatabasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Database Tools')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.medical_services),
                title: const Text('Manage Symptoms'),
                subtitle: const Text('Manage symptom classes, symptoms, and resolutions'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const ManageSymptomsPage()),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Manage Users'),
                subtitle: const Text('Manage auth users, public users, and pending users'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const UserManagementPage()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 