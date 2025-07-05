import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:io';

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
        // Firebase not available, continue with local notifications only
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
          // Continue without FCM permissions
        }
      }

      // Get FCM token
      try {
        _fcmToken = await _firebaseMessaging.getToken();
      } catch (e) {
        // Continue without FCM token
      }

      // Listen for token refresh
      try {
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          print('DEBUG: FCM token refreshed: $newToken');
          _fcmToken = newToken;
          _saveTokenToDatabase(newToken);
        });
      } catch (e) {
        print('DEBUG: Error setting up token refresh listener: $e');
      }

      // Handle foreground messages
      try {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
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
        // Continue without foreground message handling
      }

      // Handle background messages
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
        // Continue without background message handling
      }

      // Handle notification taps when app is opened from background
      try {
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          // TODO: Navigate to specific problem or screen based on message data
        });
      } catch (e) {
        // Continue without message opened handling
      }

      // Clean up device tokens and save current user's token
      await _cleanupAndSaveToken();

      // Listen for auth state changes to save token when user logs in
      _supabase.auth.onAuthStateChange.listen((event) {
        if (event.event == 'SIGNED_IN' && _fcmToken != null) {
          print('DEBUG: User signed in, saving FCM token...');
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
        // Continue without iOS permissions
      }
    } catch (e) {
      // Continue without local notifications
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
        print('DEBUG: No user ID found, cannot save token');
        return;
      }

      final platform = Platform.isIOS ? 'ios' : 'android';
      print('DEBUG: Attempting to save FCM token for user: $userId, platform: $platform');
      print('DEBUG: Token to save: ${token.substring(0, 20)}...');
      
      // Check if token already exists
      final existingToken = await _supabase
          .from('device_tokens')
          .select('id, device_token, platform')
          .eq('user_id', userId)
          .eq('device_token', token)
          .maybeSingle();

      if (existingToken == null) {
        print('DEBUG: Token does not exist, inserting new token...');
        // Insert new token
        final result = await _supabase.from('device_tokens').insert({
          'user_id': userId,
          'device_token': token,
          'platform': platform,
        });
        print('DEBUG: FCM token saved to database successfully: $result');
      } else {
        print('DEBUG: Token already exists in database');
        print('DEBUG: Existing token details: $existingToken');
      }
      
      // Also check all tokens for this user
      final allUserTokens = await _supabase
          .from('device_tokens')
          .select('*')
          .eq('user_id', userId);
      print('DEBUG: All tokens for user $userId: $allUserTokens');
      
    } catch (e) {
      print('DEBUG: Error saving FCM token to database: $e');
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
      print('DEBUG: NotificationService.sendNotification called');
      print('DEBUG: Title: $title');
      print('DEBUG: Body: $body');
      print('DEBUG: User IDs: $userIds');
      print('DEBUG: Data: $data');
      
      // Get the current user's session
      final session = _supabase.auth.currentSession;
      if (session == null) {
        print('DEBUG: No active session found');
        return false;
      }

      print('DEBUG: Calling Edge Function...');
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
          print('DEBUG: Edge Function call timed out after 30 seconds');
          throw TimeoutException('Edge Function call timed out', const Duration(seconds: 30));
        },
      );

      print('DEBUG: Edge Function response status: ${response.status}');
      print('DEBUG: Edge Function response body: ${response.data}');

      if (response.status == 200) {
        print('DEBUG: Notification sent successfully');
        return true;
      } else {
        print('DEBUG: Notification failed with status: ${response.status}');
        return false;
      }
    } catch (e) {
      print('DEBUG: Error sending notification: $e');
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
      print('DEBUG: sendNewProblemNotification called');
      print('DEBUG: crewId: $crewId');
      print('DEBUG: reporterId: $reporterId');
      
      // TEMPORARY: For debugging, include the reporter in notifications
      // TODO: Remove this after testing
      print('DEBUG: TEMPORARILY INCLUDING REPORTER IN NOTIFICATIONS FOR TESTING');
      
      // Get crew members (including the reporter for debugging)
      final crewMembers = await _supabase
          .from('crewmembers')
          .select('crewmember')
          .eq('crew', crewId);

      print('DEBUG: Found ${crewMembers.length} crew members');
      for (final member in crewMembers) {
        print('DEBUG: Crew member: ${member['crewmember']}');
      }

      if (crewMembers.isEmpty) {
        print('DEBUG: No crew members found to notify');
        return true; // Not an error, just no one to notify
      }

      final userIds = crewMembers.map((member) => member['crewmember'] as String).toList();
      print('DEBUG: User IDs to notify: $userIds');

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
      print('DEBUG: Error in sendNewProblemNotification: $e');
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
      print('DEBUG: sendProblemResolvedNotification called');
      print('DEBUG: crewId: $crewId');
      print('DEBUG: resolverId: $resolverId');
      
      // First, let's see ALL crew members for this crew
      final allCrewMembers = await _supabase
          .from('crewmembers')
          .select('crewmember')
          .eq('crew', crewId);
      
      print('DEBUG: ALL crew members for crew $crewId:');
      for (final member in allCrewMembers) {
        print('DEBUG: - ${member['crewmember']}');
      }
      
      // TEMPORARY: For debugging, send notification only to current user
      // TODO: Remove this after testing
      print('DEBUG: TEMPORARILY SENDING NOTIFICATION ONLY TO CURRENT USER FOR TESTING');
      
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        print('DEBUG: No current user found');
        return false;
      }
      
      final userIds = [currentUser.id];
      print('DEBUG: User IDs to notify (current user only): $userIds');

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
      print('DEBUG: Error in sendProblemResolvedNotification: $e');
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
    print('🚨🚨🚨 NEW sendCrewNotification CALLED! 🚨🚨🚨');
    print('🚨🚨🚨 This should be the new unified notification function! 🚨🚨🚨');
    
    try {
      print('DEBUG: sendCrewNotification called');
      print('DEBUG: Title: $title');
      print('DEBUG: Body: $body');
      print('DEBUG: Crew ID: $crewId');
      print('DEBUG: Sender ID: $senderId');
      print('DEBUG: Include reporter: $includeReporter');
      
      // Get all crew members
      final crewMembers = await _supabase
          .from('crewmembers')
          .select('crewmember')
          .eq('crew', crewId);

      print('DEBUG: Found ${crewMembers.length} crew members');
      for (final member in crewMembers) {
        print('DEBUG: Crew member: ${member['crewmember']}');
      }

      if (crewMembers.isEmpty) {
        print('DEBUG: No crew members found to notify');
        return true; // Not an error, just no one to notify
      }

      // Start with all crew members
      List<String> userIds = crewMembers.map((member) => member['crewmember'] as String).toList();
      
      // Remove sender unless includeReporter is true
      if (!includeReporter) {
        userIds.removeWhere((id) => id == senderId);
        print('DEBUG: Removed sender from notification list');
      } else {
        print('DEBUG: Including sender in notification list');
      }
      
      // TEMPORARY: For debugging, always include the sender
      // TODO: Remove this after testing
      if (!userIds.contains(senderId)) {
        print('DEBUG: TEMPORARILY ADDING SENDER TO NOTIFICATION LIST FOR TESTING');
        userIds.add(senderId);
      }
      
      print('DEBUG: Final user IDs to notify: $userIds');
      
      // DEBUG: Check if current user has device tokens
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        print('DEBUG: Current user ID: ${currentUser.id}');
        final userTokens = await _supabase
            .from('device_tokens')
            .select('*')
            .eq('user_id', currentUser.id);
        print('DEBUG: Current user device tokens: $userTokens');
      }

      return await sendNotification(
        title: title,
        body: body,
        userIds: userIds,
        data: data,
        problemId: data['problemId'],
      );
    } catch (e) {
      print('DEBUG: Error in sendCrewNotification: $e');
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
    // TODO: Implement custom in-app notification UI
    // This could be:
    // - A custom overlay widget
    // - A snackbar with custom styling
    // - A modal dialog
    // - A banner at the top of the screen
  }

  /// Clean up resources
  Future<void> dispose() async {
    try {
      // Remove all FCM tokens for current user from database
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        print('DEBUG: Cleaning up all device tokens for user: $userId');
        await _supabase
            .from('device_tokens')
            .delete()
            .eq('user_id', userId);
        print('DEBUG: Cleaned up device tokens for user: $userId');
      }
    } catch (e) {
      print('DEBUG: Error cleaning up device tokens: $e');
    }
  }

  /// Clean up device tokens and save current user's token
  Future<void> _cleanupAndSaveToken() async {
    try {
      // Clean up device tokens
      await dispose();

      // Save current user's token
      if (_fcmToken != null) {
        print('DEBUG: Saving current FCM token to database...');
        print('DEBUG: Current user: ${_supabase.auth.currentUser?.id}');
        await _saveTokenToDatabase(_fcmToken!);
      } else {
        print('DEBUG: No current FCM token to save');
      }
    } catch (e) {
      print('DEBUG: Error in _cleanupAndSaveToken: $e');
    }
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔥 BACKGROUND MESSAGE RECEIVED! 🔥');
  print('🔥 Message data: ${message.data}');
  print('🔥 Message notification: ${message.notification?.title} - ${message.notification?.body}');
  
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
    
    print('🔥 Background notification shown successfully! 🔥');
  }
} 