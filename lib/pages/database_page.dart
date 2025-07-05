import 'package:flutter/material.dart';
import 'manage_symptoms_page.dart';

class DatabasePage extends StatelessWidget {
  const DatabasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Database Tools')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ManageSymptomsPage()),
            );
          },
          child: const Text('Manage Symptom Classes, Symptoms, and Resolutions'),
        ),
      ),
    );
  }
} 