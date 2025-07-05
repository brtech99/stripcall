import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'router.dart';
import 'services/notification_service.dart';

void main() async {
  debugPrint('Starting app initialization...');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('Flutter binding initialized');

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  debugPrint('Supabase URL: ${supabaseUrl.isNotEmpty ? 'Set' : 'Not set'}');
  debugPrint('Supabase Anon Key: ${supabaseAnonKey.isNotEmpty ? 'Set' : 'Not set'}');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception('Supabase credentials not found. Please set them using --dart-define.');
  }

  debugPrint('Initializing Supabase...');
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  debugPrint('Supabase initialized successfully');

  debugPrint('Initializing Firebase...');
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    // Continue without Firebase - the app can still work for basic functionality
  }

  debugPrint('Initializing Notification Service...');
  try {
    await NotificationService().initialize();
    debugPrint('Notification Service initialized successfully');
  } catch (e) {
    debugPrint('Notification Service initialization failed: $e');
    // Continue without notifications - the app can still work for basic functionality
  }

  debugPrint('Running app...');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    debugPrint('MyApp initState called');
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        // For simplicity, this is a basic listener. The AuthStateHandler
        // was not providing significant value and has been removed.
        // The router's redirect logic handles auth state changes effectively.
        debugPrint('Auth state changed: ${event.event}');
      });
      debugPrint('Auth state listener set up');
    } catch (e) {
      debugPrint('Error setting up auth state listener: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building MyApp...');
    return MaterialApp.router(
      title: 'StripCall',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
