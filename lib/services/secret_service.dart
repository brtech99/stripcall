import 'package:supabase_flutter/supabase_flutter.dart';

class SecretService {
  static final _instance = SecretService._internal();
  factory SecretService() => _instance;
  SecretService._internal();

  final _supabase = Supabase.instance.client;
  
  // Cache secrets to avoid repeated API calls
  Map<String, dynamic>? _firebaseSecrets;
  Map<String, dynamic>? _deploymentSecrets;
  DateTime? _lastFetch;
  
  // Cache duration (5 minutes)
  static const _cacheDuration = Duration(minutes: 5);

  /// Get Firebase configuration secrets
  Future<Map<String, dynamic>> getFirebaseSecrets() async {
    if (_firebaseSecrets != null && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      return _firebaseSecrets!;
    }

    try {
      final response = await _supabase.functions.invoke(
        'get-app-secrets',
        body: {'secretType': 'firebase'},
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        throw Exception('Failed to fetch Firebase secrets: ${errorData?['error'] ?? 'Unknown error'}');
      }

      final responseData = response.data as Map<String, dynamic>;
      _firebaseSecrets = responseData['secrets'] as Map<String, dynamic>;
      _lastFetch = DateTime.now();
      
      return _firebaseSecrets!;
    } catch (e) {
      throw Exception('Error fetching Firebase secrets: $e');
    }
  }

  /// Get deployment secrets (superuser only)
  Future<Map<String, dynamic>> getDeploymentSecrets() async {
    if (_deploymentSecrets != null && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      return _deploymentSecrets!;
    }

    try {
      final response = await _supabase.functions.invoke(
        'get-app-secrets',
        body: {'secretType': 'deployment'},
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        throw Exception('Failed to fetch deployment secrets: ${errorData?['error'] ?? 'Unknown error'}');
      }

      final responseData = response.data as Map<String, dynamic>;
      _deploymentSecrets = responseData['secrets'] as Map<String, dynamic>;
      _lastFetch = DateTime.now();
      
      return _deploymentSecrets!;
    } catch (e) {
      throw Exception('Error fetching deployment secrets: $e');
    }
  }

  /// Clear cached secrets (call when user logs out)
  void clearCache() {
    _firebaseSecrets = null;
    _deploymentSecrets = null;
    _lastFetch = null;
  }

  /// Get a specific Firebase secret
  Future<String?> getFirebaseSecret(String key) async {
    final secrets = await getFirebaseSecrets();
    return secrets[key] as String?;
  }

  /// Get Firebase Web configuration
  Future<Map<String, dynamic>> getFirebaseWebConfig() async {
    final secrets = await getFirebaseSecrets();
    
    return {
      'apiKey': secrets['FIREBASE_API_KEY'],
      'appId': secrets['FIREBASE_APP_ID'],
      'messagingSenderId': secrets['FIREBASE_MESSAGING_SENDER_ID'],
      'projectId': secrets['FIREBASE_PROJECT_ID'],
      'authDomain': secrets['FIREBASE_AUTH_DOMAIN'],
      'storageBucket': secrets['FIREBASE_STORAGE_BUCKET'],
    };
  }

  /// Get Firebase VAPID key for push notifications
  Future<String?> getFirebaseVapidKey() async {
    return await getFirebaseSecret('FIREBASE_VAPID_KEY');
  }
} 