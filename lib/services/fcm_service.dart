// lib/services/fcm_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

/// Top-level function to handle background messages
/// This must be a top-level function, not a class method
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message received: ${message.messageId}');
  debugPrint('[FCM] Message data: ${message.data}');
  debugPrint('[FCM] Message notification: ${message.notification?.title}');

  // Show notification even when app is closed
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Handle different message types
  final messageType = message.data['type'] as String?;

  if (messageType == 'message') {
    await notificationService.showMessageNotification(
      senderName:
          message.data['sender_name'] as String? ??
          message.notification?.title ??
          'Nouveau message',
      message:
          message.data['message'] as String? ??
          message.notification?.body ??
          '',
      senderId: int.tryParse(message.data['sender_id']?.toString() ?? '0') ?? 0,
      messageType: message.data['message_type'] as String?,
      senderAvatar: message.data['sender_avatar'] as String?,
      payload: message.data,
    );
  } else if (messageType == 'emergency') {
    await notificationService.showEmergencyNotification(
      title:
          message.data['title'] as String? ??
          message.notification?.title ??
          'Alerte',
      message:
          message.data['message'] as String? ??
          message.notification?.body ??
          '',
      location: message.data['location'] as String? ?? '',
      requesterName: message.data['requester_name'] as String?,
      payload: message.data,
    );
  } else {
    // Generic notification from FCM
    if (message.notification != null) {
      await notificationService.showMessageNotification(
        senderName: message.notification!.title ?? 'Notification',
        message: message.notification!.body ?? '',
        senderId: 0,
        payload: message.data,
      );
    }
  }
}

/// Service for managing Firebase Cloud Messaging
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  String? _fcmToken;

  /// Initialize FCM service
  Future<void> initialize() async {
    try {
      // Check if Firebase is initialized
      try {
        // Try to get token to verify Firebase is available
        await _firebaseMessaging.getToken();
      } catch (e) {
        debugPrint(
          '[FCM] Firebase not configured. FCM push notifications will not work.',
        );
        debugPrint(
          '[FCM] Local notifications will still work when app is in background.',
        );
        debugPrint(
          '[FCM] To enable FCM: Configure google-services.json (see FCM_BACKEND_INTEGRATION.md)',
        );
        return;
      }

      // Request permission for notifications
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        _fcmToken = await _firebaseMessaging.getToken();
        debugPrint('[FCM] FCM Token: $_fcmToken');

        // Save token to backend if needed
        if (_fcmToken != null) {
          await _saveTokenToBackend(_fcmToken!);
        }

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          debugPrint('[FCM] Token refreshed: $newToken');
          _fcmToken = newToken;
          _saveTokenToBackend(newToken);
        });

        // Set up background message handler
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle notification taps when app is opened from terminated state
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // Check if app was opened from a notification
        final initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
      }
    } catch (e) {
      debugPrint('[FCM] Error initializing FCM: $e');
    }
  }

  /// Handle foreground messages (when app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Foreground message received: ${message.messageId}');
    debugPrint('[FCM] Message data: ${message.data}');

    // Show notification even in foreground
    final notificationService = NotificationService();
    await notificationService.initialize();

    final messageType = message.data['type'] as String?;

    if (messageType == 'message') {
      await notificationService.showMessageNotification(
        senderName:
            message.data['sender_name'] as String? ??
            message.notification?.title ??
            'Nouveau message',
        message:
            message.data['message'] as String? ??
            message.notification?.body ??
            '',
        senderId:
            int.tryParse(message.data['sender_id']?.toString() ?? '0') ?? 0,
        messageType: message.data['message_type'] as String?,
        senderAvatar: message.data['sender_avatar'] as String?,
        payload: message.data,
      );
    } else if (messageType == 'emergency') {
      await notificationService.showEmergencyNotification(
        title:
            message.data['title'] as String? ??
            message.notification?.title ??
            'Alerte',
        message:
            message.data['message'] as String? ??
            message.notification?.body ??
            '',
        location: message.data['location'] as String? ?? '',
        requesterName: message.data['requester_name'] as String?,
        payload: message.data,
      );
    }
  }

  /// Handle notification tap (opens app)
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] Notification tapped, opening app: ${message.messageId}');
    debugPrint('[FCM] Message data: ${message.data}');

    // You can add navigation logic here based on message data
    // For example, navigate to chat screen, etc.
  }

  /// Save FCM token to backend
  /// TODO: Implement this by importing your API client and calling your backend
  Future<void> _saveTokenToBackend(String token) async {
    try {
      // TODO: Implement API call to save FCM token to your backend
      // You need to:
      // 1. Import your API client (e.g., ApiClient from core/network/api_client.dart)
      // 2. Get current user ID from auth provider
      // 3. Call your backend API endpoint to save the token
      //
      // Example implementation (uncomment and modify):
      // final apiClient = ApiClient();
      // final user = await getCurrentUser(); // Get from your auth service
      // await apiClient.post(
      //   '/fcm-token',
      //   body: {
      //     'token': token,
      //     'user_id': user.id,
      //     'platform': Platform.isAndroid ? 'android' : 'ios',
      //   },
      //   requireAuth: true,
      // );

      debugPrint('[FCM] Token to be saved: $token');
      debugPrint(
        '[FCM] TODO: Implement backend API call in _saveTokenToBackend method',
      );
      debugPrint(
        '[FCM] See FCM_BACKEND_INTEGRATION.md for implementation guide',
      );
    } catch (e) {
      debugPrint('[FCM] Error saving token to backend: $e');
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('[FCM] Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('[FCM] Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('[FCM] Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('[FCM] Error unsubscribing from topic: $e');
    }
  }
}
