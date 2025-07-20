import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'router.dart';
import 'services/notification_service.dart';
import 'utils/debug_utils.dart';

void main() async {
  print('=== MAIN: App starting ===');
  WidgetsFlutterBinding.ensureInitialized();

  debugLog('=== APP STARTING ===');
  debugLog('Debug logging is working!');

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception('Missing Supabase environment variables');
  }

  debugLog('Supabase URL: $supabaseUrl');
  debugLog('Supabase Anon Key: ${supabaseAnonKey.substring(0, 20)}...');

  // Debug Firebase environment variables
  const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  
  debugLog('Firebase API Key: ${firebaseApiKey.isNotEmpty ? "${firebaseApiKey.substring(0, 10)}..." : "NOT SET"}');
  debugLog('Firebase App ID: ${firebaseAppId.isNotEmpty ? firebaseAppId : "NOT SET"}');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  debugLog('Supabase initialized successfully');

  try {
    debugLog('Starting Firebase initialization...');
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
        authDomain: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
        messagingSenderId: const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
        appId: const String.fromEnvironment('FIREBASE_APP_ID'),
      ),
    );
    debugLog('Firebase initialized successfully');
  } catch (e) {
    debugLogError('Firebase initialization failed, but we can continue without it', e);
  }

  try {
    debugLog('Starting notification service initialization...');
    await NotificationService().initialize();
    debugLog('Notification service initialized successfully');
  } catch (e) {
    debugLogError('Notification service initialization failed, but we can continue without it', e);
  }

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
    
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      // Auth state changes are handled by the router
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'StripCall',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
