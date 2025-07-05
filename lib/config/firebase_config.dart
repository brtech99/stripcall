class FirebaseConfig {
  // Replace this with your actual Firebase Server Key
  // You can find this in your Firebase Console:
  // Project Settings > Cloud Messaging > Server key
  static const String serverKey = 'YOUR_FIREBASE_SERVER_KEY_HERE';
  
  // Firebase project configuration
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
} 