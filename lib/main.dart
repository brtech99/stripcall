import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'router.dart';
import 'services/notification_service.dart';
import 'utils/debug_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception('Missing Supabase environment variables');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugLogError('Firebase initialization failed, but we can continue without it', e);
  }

  try {
    await NotificationService().initialize();
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
