import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'router.dart';
import 'services/notification_service.dart';
import 'services/secret_service.dart';
import 'config/firebase_config.dart';
import 'utils/debug_utils.dart';
import 'theme/theme.dart';

void main() async {
  debugLog('=== STRIPCALL BUILD 2026-01-21-TEST ===');
  WidgetsFlutterBinding.ensureInitialized();

  debugLog('=== APP STARTING ===');
  debugLog('Debug logging is working!');

  // Get Supabase credentials from environment (passed via --dart-define)
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception('Missing Supabase environment variables');
  }

  debugLog('Supabase URL: $supabaseUrl');
  debugLog('Supabase Anon Key: ${supabaseAnonKey.substring(0, 20)}...');

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  debugLog('Supabase initialized successfully');
  debugLog(
    '🔐 Firebase secrets will be fetched from Vault after user authentication',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeApp();

    // Listen for auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn) {
        _initializeFirebaseAfterAuth();
      } else if (event.event == AuthChangeEvent.signedOut) {
        // Clear cached secrets when user logs out
        SecretService().clearCache();
      }
    });

    // If user is already logged in, initialize Firebase now
    if (Supabase.instance.client.auth.currentSession != null) {
      _initializeFirebaseAfterAuth();
    }
  }

  Future<void> _initializeApp() async {
    try {
      // App is ready to show login screen
      setState(() {
        _isInitialized = true;
      });

      debugLog('✅ App initialization completed - ready for login');
    } catch (e) {
      debugLogError('App initialization failed', e);
      setState(() {
        _error = e.toString();
        _isInitialized = true;
      });
    }
  }

  Future<void> _initializeFirebaseAfterAuth() async {
    try {
      debugLog('🔐 User authenticated, initializing Firebase...');

      // On mobile (iOS/Android), Firebase uses native config files (google-services.json / GoogleService-Info.plist)
      // On web, we need to pass the config explicitly from Vault
      if (kIsWeb) {
        // Get Firebase config from Vault for web
        final firebaseConfig = await FirebaseConfig.getWebConfig();
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: firebaseConfig['apiKey'],
            authDomain: firebaseConfig['authDomain'],
            projectId: firebaseConfig['projectId'],
            storageBucket: firebaseConfig['storageBucket'],
            messagingSenderId: firebaseConfig['messagingSenderId'],
            appId: firebaseConfig['appId'],
          ),
        );
        debugLog('✅ Firebase initialized with Vault secrets (web)');
      } else {
        // On mobile, just initialize - it will use google-services.json / GoogleService-Info.plist
        await Firebase.initializeApp();
        debugLog('✅ Firebase initialized with native config (mobile)');
      }

      // Initialize notification service (skip in test mode to avoid native permission dialog)
      const skipNotifications = bool.fromEnvironment('SKIP_NOTIFICATIONS');
      if (skipNotifications) {
        debugLog('⏭️ Skipping notification service (SKIP_NOTIFICATIONS=true)');
      } else {
        try {
          await NotificationService().initialize();
          debugLog('✅ Notification service initialized');
        } catch (e) {
          debugLogError(
            'Notification service initialization failed, continuing without it',
            e,
          );
        }
      }
    } catch (e) {
      debugLogError('Firebase initialization failed', e);
      // Continue without Firebase - the app should still work
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                AppSpacing.verticalMd,
                const Text('Initializing StripCall...'),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: AppColors.statusError, size: 64),
                AppSpacing.verticalMd,
                Text(
                  'Initialization Error:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                AppSpacing.verticalSm,
                Text(_error!, textAlign: TextAlign.center),
                AppSpacing.verticalMd,
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isInitialized = false;
                      _error = null;
                    });
                    _initializeApp();
                  },
                  child: Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: 'StripCall',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
