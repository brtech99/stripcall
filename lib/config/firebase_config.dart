import '../services/secret_service.dart';

class FirebaseConfig {
  static final _secretService = SecretService();
  
  // Static project info (non-sensitive)
  static const String projectId = 'stripcalls-458912';
  
  // Notification settings
  static const bool enableNotifications = true;
  static const bool enableSound = true;
  static const bool enableVibration = true;
  
  // Notification types to enable
  static const bool enableNewProblemNotifications = true;
  static const bool enableResponseNotifications = true;
  static const bool enableResolutionNotifications = true;
  static const bool enableMessageNotifications = true;

  /// Get Firebase web configuration from Vault
  static Future<Map<String, dynamic>> getWebConfig() async {
    return await _secretService.getFirebaseWebConfig();
  }

  /// Get Firebase server key from Vault
  static Future<String?> getServerKey() async {
    return await _secretService.getFirebaseSecret('FIREBASE_API_KEY');
  }

  /// Get VAPID key for push notifications
  static Future<String?> getVapidKey() async {
    return await _secretService.getFirebaseVapidKey();
  }
} 