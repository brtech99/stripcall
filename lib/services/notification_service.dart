import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:js' as js;
import '../utils/debug_utils.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  String? _fcmToken;
  bool _isInitialized = false;

  /// Initialize Firebase, request permissions, and set up local notifications
  Future<void> initialize() async {
    print('=== NOTIFICATION SERVICE: Initialize called ===');
    if (_isInitialized) {
      print('=== NOTIFICATION SERVICE: Already initialized, returning ===');
      return;
    }

    try {
      print('=== NOTIFICATION SERVICE: Starting initialization ===');
      // Initialize Firebase
      try {
        await Firebase.initializeApp();
      } catch (e) {
        debugLogError('Firebase not available, continue with local notifications only', e);
        _isInitialized = true;
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request permission for iOS and Web
      if (Platform.isIOS || kIsWeb) {
        try {
          debugLog('Requesting notification permissions...');
          print('Requesting notification permissions from Dart side...');
          NotificationSettings settings = await _firebaseMessaging.requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );
          
          debugLog('Notification permission status: ${settings.authorizationStatus}');
          print('Notification permission status: ${settings.authorizationStatus}');
          if (settings.authorizationStatus == AuthorizationStatus.authorized) {
            debugLog('Notification permission granted');
            print('Notification permission granted');
          } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
            debugLog('Provisional notification permission granted');
            print('Provisional notification permission granted');
          } else {
            debugLog('Notification permission denied: ${settings.authorizationStatus}');
            print('Notification permission denied: ${settings.authorizationStatus}');
          }
        } catch (e) {
          debugLogError('Continue without FCM permissions', e);
          print('Error requesting notification permissions: $e');
        }
      }

      // Get FCM token
      try {
        debugLog('Requesting FCM token...');
        print('Requesting FCM token from Dart side...');
        _fcmToken = await _firebaseMessaging.getToken();
        if (_fcmToken != null) {
          debugLog('FCM token obtained: ${_fcmToken!.substring(0, 20)}...');
          print('FCM token obtained from Dart: ${_fcmToken!.substring(0, 20)}...');
        } else {
          debugLog('No FCM token obtained');
          print('No FCM token obtained from Dart side');
          
          // Try to get token from JavaScript side as fallback
          try {
            print('Trying to get FCM token from JavaScript side...');
            final jsToken = js.context.callMethod('getFCMToken');
            if (jsToken != null) {
              _fcmToken = jsToken.toString();
              print('FCM token obtained from JavaScript: ${_fcmToken!.substring(0, 20)}...');
            } else {
              print('JavaScript token is null, waiting and retrying...');
              // Wait a bit and try again
              await Future.delayed(const Duration(seconds: 2));
              final retryToken = js.context.callMethod('getFCMToken');
              if (retryToken != null) {
                _fcmToken = retryToken.toString();
                print('FCM token obtained from JavaScript on retry: ${_fcmToken!.substring(0, 20)}...');
              }
            }
          } catch (jsError) {
            print('Failed to get FCM token from JavaScript: $jsError');
          }
        }
      } catch (e) {
        debugLogError('Continue without FCM token', e);
        print('Error getting FCM token from Dart: $e');
      }

      // Listen for token refresh
      try {
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          debugLog('FCM token refreshed');
          _fcmToken = newToken;
          _saveTokenToDatabase(newToken);
        });
      } catch (e) {
        debugLogError('Error setting up token refresh listener', e);
      }

      // Handle foreground messages
      try {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugLog('Received foreground message: ${message.notification?.title}');
          // For foreground messages, we'll show a custom in-app notification
          // instead of relying on system notification banner
          if (message.notification != null) {
            _showCustomInAppNotification(
              message.notification!.title ?? 'New Message',
              message.notification!.body ?? '',
              message.data,
            );
          }
        });
      } catch (e) {
        debugLogError('Error setting up foreground message handler', e);
      }

      // Handle background messages
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
        debugLogError('Continue without background message handling', e);
      }

      // Handle notification taps when app is opened from background
      try {
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          // TODO: Navigate to specific problem or screen based on message data
        });
      } catch (e) {
        debugLogError('Continue without message opened handling', e);
      }

      // Clean up device tokens and save current user's token
      await _cleanupAndSaveToken();

      // Listen for auth state changes to save token when user logs in
      _supabase.auth.onAuthStateChange.listen((event) {
        if (event.event == AuthChangeEvent.signedIn && _fcmToken != null) {
          debugLog('User signed in, saving FCM token to database...');
          _saveTokenToDatabase(_fcmToken!);
        }
      });

      // Also save token immediately if user is already logged in
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null && _fcmToken != null) {
        debugLog('User already logged in, saving FCM token to database...');
        _saveTokenToDatabase(_fcmToken!);
      }

      _isInitialized = true;

    } catch (e) {
      _isInitialized = true; // Mark as initialized to prevent retry loops
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(initSettings);
      
      // Create notification channel for Android (iOS doesn't use channels)
      try {
        const androidChannel = AndroidNotificationChannel(
          'stripcall_channel',
          'StripCall Notifications',
          description: 'Notifications for StripCall app',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );
        
        final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(androidChannel);
        }
      } catch (e) {
        debugLogError('Error creating Android notification channel', e);
      }
      
      // Request permissions explicitly for iOS
      try {
        final iosPlugin = _localNotifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        
        if (iosPlugin != null) {
          await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
        }
      } catch (e) {
        debugLogError('Continue without iOS permissions', e);
      }
    } catch (e) {
      debugLogError('Continue without local notifications', e);
    }
  }

  /// Show a local notification
  Future<void> _showLocalNotification(
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'stripcall_channel',
        'StripCall Notifications',
        channelDescription: 'Notifications for StripCall app',
        importance: Importance.high,
        priority: Priority.high,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: data != null ? json.encode(data) : null,
      );
    } catch (e) {
      // Silently fail for local notifications
    }
  }

  /// Save FCM token to Supabase database
  Future<void> _saveTokenToDatabase(String token) async {
    try {
      debugLog('=== Starting _saveTokenToDatabase ===');
      debugLog('Token length: ${token.length}');
      debugLog('Token preview: ${token.substring(0, 20)}...');
      
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugLogError('No current user found, cannot save FCM token');
        return;
      }

      debugLog('Current user ID: $userId');
      debugLog('User ID type: ${userId.runtimeType}');
      
      final platform = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');
      debugLog('Platform: $platform');
      
      // First, let's check if the device_tokens table exists by trying to query it
      try {
        debugLog('Checking if device_tokens table exists...');
        final tableCheck = await _supabase.from('device_tokens').select('count').limit(1);
        debugLog('device_tokens table exists, check result: $tableCheck');
      } catch (e) {
        debugLogError('device_tokens table does not exist or is not accessible', e);
        debugLogError('You need to create the device_tokens table in your Supabase database');
        return;
      }
      
      // Check if token already exists
      debugLog('Checking if token already exists...');
      final existingToken = await _supabase
          .from('device_tokens')
          .select('id, device_token, platform')
          .eq('user_id', userId)
          .eq('device_token', token)
          .maybeSingle();

      debugLog('Existing token check result: $existingToken');

      if (existingToken == null) {
        debugLog('Token does not exist, inserting new token...');
        debugLog('Insert data: {"user_id": "$userId", "device_token": "${token.substring(0, 20)}...", "platform": "$platform"}');
        
        // Insert new token
        final result = await _supabase.from('device_tokens').insert({
          'user_id': userId,
          'device_token': token,
          'platform': platform,
        });
        debugLog('Insert result: $result');
      } else {
        debugLog('Token already exists, skipping insert');
      }
      
      debugLog('FCM token saved to database successfully');
    } catch (e) {
      debugLogError('Error saving FCM token to database', e);
      debugLogError('Error details: ${e.toString()}');
      debugLogError('Error type: ${e.runtimeType}');
      if (e is PostgrestException) {
        debugLogError('PostgrestException message: ${e.message}');
        debugLogError('PostgrestException details: ${e.details}');
        debugLogError('PostgrestException hint: ${e.hint}');
      }
      rethrow; // Re-throw so the calling method can handle it
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Check if notifications are available
  bool get isAvailable => _isInitialized && _fcmToken != null;

  /// Save FCM token to database manually
  Future<bool> saveTokenToDatabase() async {
    try {
      print('=== STARTING SAVE TOKEN TO DATABASE ===');
      debugLog('=== Starting saveTokenToDatabase ===');
      print('Save token method called - this should appear in console');
      
      // Try to get fresh token from JavaScript first
      try {
        print('Trying to get fresh FCM token from JavaScript...');
        final jsToken = js.context.callMethod('getFCMToken');
        if (jsToken != null) {
          _fcmToken = jsToken.toString();
          print('Fresh FCM token obtained from JavaScript: ${_fcmToken!.substring(0, 20)}...');
        }
      } catch (jsError) {
        print('Failed to get fresh FCM token from JavaScript: $jsError');
      }
      
      if (_fcmToken == null) {
        print('ERROR: No FCM token available to save');
        debugLog('No FCM token available to save');
        return false;
      }
      
      print('FCM token is available, proceeding...');
      
      debugLog('FCM token available: ${_fcmToken!.substring(0, 20)}...');
      debugLog('Manually saving FCM token to database...');
      print('About to call _saveTokenToDatabase...');
      
      await _saveTokenToDatabase(_fcmToken!);
      print('_saveTokenToDatabase completed successfully');
      debugLog('FCM token saved to database successfully');
      return true;
    } catch (e) {
      print('ERROR in saveTokenToDatabase: $e');
      print('ERROR type: ${e.runtimeType}');
      debugLogError('Error saving FCM token to database', e);
      debugLogError('Full error details: ${e.toString()}');
      debugLogError('Error type: ${e.runtimeType}');
      if (e is PostgrestException) {
        print('PostgrestException message: ${e.message}');
        print('PostgrestException details: ${e.details}');
        debugLogError('PostgrestException details: ${e.message}');
        debugLogError('PostgrestException details: ${e.details}');
      }
      return false;
    }
  }

  /// Test database connection and table access
  Future<bool> testDatabaseConnection() async {
    try {
      print('=== TESTING DATABASE CONNECTION ===');
      debugLog('=== Testing database connection ===');
      print('Debug logging test - this should appear in console');
      
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugLogError('No current user found');
        return false;
      }
      
      debugLog('Current user ID: $userId');
      debugLog('User ID type: ${userId.runtimeType}');
      
      // Test basic connection
      try {
        final result = await _supabase.from('device_tokens').select('count').limit(1);
        debugLog('Database connection successful');
        debugLog('device_tokens table accessible');
        debugLog('Query result: $result');
        
        // Test RLS policy by trying to insert a test record
        debugLog('Testing RLS policy with insert...');
        try {
          final testResult = await _supabase.from('device_tokens').insert({
            'user_id': userId,
            'device_token': 'test_token_${DateTime.now().millisecondsSinceEpoch}',
            'platform': 'web',
          });
          debugLog('RLS policy test successful - insert worked');
          
          // Clean up the test record
          await _supabase.from('device_tokens')
              .delete()
              .eq('device_token', 'test_token_${DateTime.now().millisecondsSinceEpoch}');
          debugLog('Test record cleaned up');
          
        } catch (e) {
          debugLogError('RLS policy test failed - insert blocked', e);
          debugLogError('RLS error details: ${e.toString()}');
          return false;
        }
        
        return true;
      } catch (e) {
        debugLogError('Database connection failed', e);
        debugLogError('Error details: ${e.toString()}');
        return false;
      }
    } catch (e) {
      debugLogError('Error testing database connection', e);
      return false;
    }
  }

  /// Test method to show a local notification directly
  Future<bool> testLocalNotification() async {
    try {
      debugLog('Testing local notification...');
      print('=== Testing local notification ===');
      
      if (_fcmToken != null) {
        debugLog('FCM token available: ${_fcmToken!.substring(0, 20)}...');
        print('FCM token available: ${_fcmToken!.substring(0, 20)}...');
      } else {
        debugLog('No FCM token available');
        print('No FCM token available');
      }

      // For web, we can show a notification directly
      if (kIsWeb) {
        debugLog('Showing web notification...');
        print('Showing web notification...');
        
        // Try to call the JavaScript function if it exists
        try {
          // This will call the JavaScript function we added to firebase-config.js
          print('Calling JavaScript testLocalNotification function...');
          js.context.callMethod('testLocalNotification');
          debugLog('JavaScript notification function called');
          print('JavaScript notification function called successfully');
          return true;
        } catch (e) {
          debugLogError('Error calling JavaScript notification function', e);
          print('Error calling JavaScript notification function: $e');
          return false;
        }
      }

      return false;
    } catch (e) {
      debugLogError('Error testing local notification', e);
      print('Error testing local notification: $e');
      return false;
    }
  }

  /// Send a notification to specific users via the Edge Function
  Future<bool> sendNotification({
    required String title,
    required String body,
    required List<String> userIds,
    Map<String, dynamic>? data,
    String? problemId,
  }) async {
    try {
      debugLog('Sending notification: $title - $body to ${userIds.length} users');
      
      // Get the current user's session
      final session = _supabase.auth.currentSession;
      if (session == null) {
        debugLogError('No active session found');
        return false;
      }

      final response = await _supabase.functions.invoke(
        'send-fcm-notification',
        body: {
          'title': title,
          'body': body,
          'userIds': userIds,
          'data': data,
          'problemId': problemId,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Edge Function call timed out', const Duration(seconds: 30));
        },
      );

      debugLog('Notification response: ${response.status}');
      return response.status == 200;
    } catch (e) {
      debugLogError('Error sending notification', e);
      return false;
    }
  }

  /// Send notification for a new problem
  /// @deprecated Use sendCrewNotification instead
  Future<bool> sendNewProblemNotification({
    required String problemTitle,
    required String crewId,
    required String problemId,
    required String reporterId,
  }) async {
    try {
      // Get crew members
      final crewMembers = await _supabase
          .from('crewmembers')
          .select('crewmember')
          .eq('crew', crewId);

      if (crewMembers.isEmpty) {
        return true; // Not an error, just no one to notify
      }

      final userIds = crewMembers.map((member) => member['crewmember'] as String).toList();

      return await sendNotification(
        title: 'New Problem Reported',
        body: problemTitle,
        userIds: userIds,
        data: {
          'type': 'new_problem',
          'problemId': problemId,
          'crewId': crewId,
        },
        problemId: problemId,
      );
    } catch (e) {
      debugLogError('Error sending new problem notification', e);
      return false;
    }
  }

  /// Send notification for problem resolution
  /// @deprecated Use sendCrewNotification instead
  Future<bool> sendProblemResolvedNotification({
    required String problemTitle,
    required String crewId,
    required String problemId,
    required String resolverId,
  }) async {
    try {
      // Get crew members
      final crewMembers = await _supabase
          .from('crewmembers')
          .select('crewmember')
          .eq('crew', crewId);

      if (crewMembers.isEmpty) {
        return true; // Not an error, just no one to notify
      }

      final userIds = crewMembers.map((member) => member['crewmember'] as String).toList();

      return await sendNotification(
        title: 'Problem Resolved',
        body: '$problemTitle has been resolved',
        userIds: userIds,
        data: {
          'type': 'problem_resolved',
          'problemId': problemId,
          'crewId': crewId,
        },
        problemId: problemId,
      );
    } catch (e) {
      debugLogError('Error sending problem resolved notification', e);
      return false;
    }
  }

  /// Send notification for new message
  /// @deprecated Use sendCrewNotification instead
  Future<bool> sendNewMessageNotification({
    required String message,
    required String crewId,
    required String problemId,
    required String senderId,
  }) async {
    try {
      // Get crew members (excluding the sender)
      final crewMembers = await _supabase
          .from('crewmembers')
          .select('crewmember')
          .eq('crew', crewId)
          .neq('crewmember', senderId);

      if (crewMembers.isEmpty) {
        return true;
      }

      final userIds = crewMembers.map((member) => member['crewmember'] as String).toList();

      return await sendNotification(
        title: 'New Message',
        body: message.length > 50 ? '${message.substring(0, 50)}...' : message,
        userIds: userIds,
        data: {
          'type': 'new_message',
          'problemId': problemId,
          'crewId': crewId,
        },
        problemId: problemId,
      );
    } catch (e) {
      debugLogError('Error sending new message notification', e);
      return false;
    }
  }

  /// Unified function to send notifications to crew members
  /// This replaces the individual notification functions with consistent logic
  Future<bool> sendCrewNotification({
    required String title,
    required String body,
    required String crewId,
    required String senderId,
    required Map<String, dynamic> data,
    bool includeReporter = false,
  }) async {
    try {
      // Get all crew members
      final crewMembers = await _supabase
          .from('crewmembers')
          .select('crewmember')
          .eq('crew', crewId);

      if (crewMembers.isEmpty) {
        return true; // Not an error, just no one to notify
      }

      // Start with all crew members
      List<String> userIds = crewMembers.map((member) => member['crewmember'] as String).toList();
      
      // Remove sender unless includeReporter is true
      if (!includeReporter) {
        userIds.removeWhere((id) => id == senderId);
      }

      return await sendNotification(
        title: title,
        body: body,
        userIds: userIds,
        data: data,
        problemId: data['problemId'],
      );
    } catch (e) {
      return false;
    }
  }

  /// Subscribe to topic for crew-specific notifications
  Future<void> subscribeToCrewTopic(String crewId) async {
    try {
      await _firebaseMessaging.subscribeToTopic('crew_$crewId');
    } catch (e) {
      // Silently fail for topic subscription
    }
  }

  /// Unsubscribe from crew topic
  Future<void> unsubscribeFromCrewTopic(String crewId) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic('crew_$crewId');
    } catch (e) {
      // Silently fail for topic unsubscription
    }
  }

  /// Subscribe to event topic
  Future<void> subscribeToEventTopic(String eventId) async {
    try {
      await _firebaseMessaging.subscribeToTopic('event_$eventId');
    } catch (e) {
      // Silently fail for topic subscription
    }
  }

  /// Unsubscribe from event topic
  Future<void> unsubscribeFromEventTopic(String eventId) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic('event_$eventId');
    } catch (e) {
      // Silently fail for topic unsubscription
    }
  }

  /// Show a custom in-app notification for foreground messages
  void _showCustomInAppNotification(
    String title,
    String body,
    Map<String, dynamic>? data,
  ) {
    // Don't show local notifications for foreground messages
    // The background handler will show the notification when the message arrives
    // This prevents duplicate notifications
  }

  /// Clean up resources
  Future<void> dispose() async {
    try {
      // Remove all FCM tokens for current user from database
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase
            .from('device_tokens')
            .delete()
            .eq('user_id', userId);
      }
    } catch (e) {
      // Error cleaning up device tokens
    }
  }

  /// Clean up device tokens and save current user's token
  Future<void> _cleanupAndSaveToken() async {
    try {
      // Clean up device tokens
      await dispose();

      // Save current user's token
      if (_fcmToken != null) {
        await _saveTokenToDatabase(_fcmToken!);
      }
    } catch (e) {
      // Error in cleanup and save token
    }
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background processing
  await Firebase.initializeApp();
  
  // Initialize local notifications for background messages
  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
  
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await localNotifications.initialize(initSettings);
  
  // Show local notification for background messages
  if (message.notification != null) {
    const androidDetails = AndroidNotificationDetails(
      'stripcall_channel',
      'StripCall Notifications',
      channelDescription: 'Notifications for StripCall app',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification!.title ?? 'New Message',
      message.notification!.body ?? '',
      details,
      payload: message.data.isNotEmpty ? json.encode(message.data) : null,
    );
  }
} 