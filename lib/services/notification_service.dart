import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:io';
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
    if (_isInitialized) {
      return;
    }

    try {
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

      // Request permission for iOS
      if (Platform.isIOS) {
        try {
          NotificationSettings settings = await _firebaseMessaging.requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );
          
          if (settings.authorizationStatus == AuthorizationStatus.authorized) {
            // Permission granted
          } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
            // Provisional permission granted
          }
        } catch (e) {
          debugLogError('Continue without FCM permissions', e);
        }
      }

      // Get FCM token
      try {
        _fcmToken = await _firebaseMessaging.getToken();
      } catch (e) {
        debugLogError('Continue without FCM token', e);
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
          _saveTokenToDatabase(_fcmToken!);
        }
      });

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
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return;
      }

      final platform = Platform.isIOS ? 'ios' : 'android';
      
      // Check if token already exists
      final existingToken = await _supabase
          .from('device_tokens')
          .select('id, device_token, platform')
          .eq('user_id', userId)
          .eq('device_token', token)
          .maybeSingle();

      if (existingToken == null) {
        // Insert new token
        await _supabase.from('device_tokens').insert({
          'user_id': userId,
          'device_token': token,
          'platform': platform,
        });
      }
      
    } catch (e) {
      debugLogError('Error saving FCM token to database', e);
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Check if notifications are available
  bool get isAvailable => _isInitialized && _fcmToken != null;

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