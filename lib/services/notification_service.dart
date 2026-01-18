// lib/services/notification_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// Service for handling WhatsApp-like notifications for chat messages
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _messageNotificationId = 1000;
  int _emergencyNotificationId = 2000;

  // Track message count per sender for grouping
  final Map<String, int> _messageCounts = {};

  // Notification channel IDs
  static const String _messageChannelId = 'chat_messages';
  static const String _emergencyChannelId = 'emergency_alerts';
  static const String _messageChannelName = 'Messages';
  static const String _emergencyChannelName = 'Urgences';

  /// Initialize the notification service
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      // Initialize timezone
      tz.initializeTimeZones();
      tz.setLocalLocation(
          tz.getLocation('Africa/Casablanca')); // Adjust to your timezone

      // Initialize Android settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Initialize iOS settings
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Initialize plugin
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels for Android
      if (Platform.isAndroid) {
        await _createAndroidChannels();
      }

      // Request permissions for iOS
      if (Platform.isIOS) {
        await _requestIOSPermissions();
      }

      _initialized = true;
      debugPrint('[NotificationService] Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
      return false;
    }
  }

  /// Create Android notification channels
  Future<void> _createAndroidChannels() async {
    // Message channel - High importance (like WhatsApp)
    const AndroidNotificationChannel messageChannel =
        AndroidNotificationChannel(
      _messageChannelId,
      _messageChannelName,
      description: 'Notifications pour les messages de chat',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      // Sound will use default system notification sound
    );

    // Emergency channel - Max importance
    const AndroidNotificationChannel emergencyChannel =
        AndroidNotificationChannel(
      _emergencyChannelId,
      _emergencyChannelName,
      description: 'Notifications pour les alertes d\'urgence',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      // Sound will use default system notification sound
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(messageChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(emergencyChannel);
  }

  /// Request iOS notification permissions
  Future<void> _requestIOSPermissions() async {
    final iOSImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iOSImplementation != null) {
      await iOSImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
        '[NotificationService] Notification tapped: ${response.payload}');
    // You can add navigation logic here based on the payload
  }

  /// Show a WhatsApp-like notification for a chat message
  Future<void> showMessageNotification({
    required String senderName,
    required String message,
    required int senderId,
    String? senderAvatar,
    String? messageType,
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Increment message count for this sender (for grouping)
      final senderKey = senderId.toString();
      _messageCounts[senderKey] = (_messageCounts[senderKey] ?? 0) + 1;
      final messageCount = _messageCounts[senderKey]!;

      // Truncate long messages (like WhatsApp)
      final truncatedMessage =
          message.length > 100 ? '${message.substring(0, 100)}...' : message;

      // Build notification title and body
      String title;
      String body;

      if (messageCount > 1) {
        // Grouped notification: "Sender Name (2)" when multiple messages
        title = '$senderName ($messageCount)';
        body = truncatedMessage;
      } else {
        // Single message: show sender name and message
        title = senderName;
        body = truncatedMessage;
      }

      // Add message type emoji if present
      final emoji = _getMessageTypeEmoji(messageType);
      if (emoji.isNotEmpty) {
        title = '$emoji $title';
      }

      // Android notification details
      final androidDetails = AndroidNotificationDetails(
        _messageChannelId,
        _messageChannelName,
        channelDescription: 'Notifications pour les messages de chat',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        styleInformation: _buildMessageStyle(senderName, message, messageCount),
        groupKey: 'chat_messages_group',
        setAsGroupSummary: false,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF25D366), // WhatsApp green color
        ledColor: const Color(0xFF25D366),
        ledOnMs: 1000,
        ledOffMs: 500,
        // Large icon from avatar if available (only for local file paths)
        largeIcon: senderAvatar != null && senderAvatar.startsWith('/')
            ? FilePathAndroidBitmap(senderAvatar)
            : null,
      );

      // iOS notification details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        // Uses default iOS notification sound
        badgeNumber: 1,
        threadIdentifier: 'chat_messages',
        categoryIdentifier: 'MESSAGE_CATEGORY',
      );

      // Notification details
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Calculate notification ID (use sender ID to group notifications)
      final notificationId = _messageNotificationId + senderId;

      // Show notification
      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload?.toString(),
      );

      // Show summary notification for Android (WhatsApp style grouping)
      if (Platform.isAndroid && messageCount > 1) {
        await _showGroupSummaryNotification();
      }

      debugPrint(
          '[NotificationService] Message notification shown: $senderName - $truncatedMessage');
    } catch (e) {
      debugPrint(
          '[NotificationService] Error showing message notification: $e');
    }
  }

  /// Build message style for Android (conversation-style like WhatsApp)
  StyleInformation _buildMessageStyle(
      String senderName, String message, int messageCount) {
    if (messageCount > 1) {
      // Use inbox style for multiple messages
      return InboxStyleInformation(
        [message],
        htmlFormatLines: false,
        contentTitle: senderName,
        summaryText: '$messageCount messages',
      );
    } else {
      // Use big text style for single message
      return BigTextStyleInformation(
        message,
        htmlFormatBigText: false,
        contentTitle: senderName,
        summaryText: '',
      );
    }
  }

  /// Show group summary notification (Android)
  Future<void> _showGroupSummaryNotification() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        _messageChannelId,
        _messageChannelName,
        channelDescription: 'Notifications pour les messages de chat',
        importance: Importance.high,
        priority: Priority.high,
        groupKey: 'chat_messages_group',
        setAsGroupSummary: true,
        enableVibration: false,
        playSound: false,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF25D366),
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notifications.show(
        999,
        'Nouveaux messages',
        'Vous avez de nouveaux messages',
        notificationDetails,
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing group summary: $e');
    }
  }

  /// Show emergency alert notification
  Future<void> showEmergencyNotification({
    required String title,
    required String message,
    required String location,
    String? requesterName,
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final notificationId = _emergencyNotificationId++;
      final body = location.isNotEmpty ? '$message\n📍 $location' : message;

      const androidDetails = AndroidNotificationDetails(
        _emergencyChannelId,
        _emergencyChannelName,
        channelDescription: 'Notifications pour les alertes d\'urgence',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        color: Colors.red,
        ledColor: Colors.red,
        ledOnMs: 500,
        ledOffMs: 500,
        styleInformation: BigTextStyleInformation(''),
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        // Uses default iOS notification sound
        interruptionLevel: InterruptionLevel.critical,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        notificationId,
        '🚨 $title',
        body,
        notificationDetails,
        payload: payload?.toString(),
      );

      debugPrint('[NotificationService] Emergency notification shown: $title');
    } catch (e) {
      debugPrint(
          '[NotificationService] Error showing emergency notification: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    await _notifications.cancelAll();
    _messageCounts.clear();
    debugPrint('[NotificationService] All notifications cleared');
  }

  /// Clear notifications for a specific sender
  Future<void> clearSenderNotifications(int senderId) async {
    final notificationId = _messageNotificationId + senderId;
    await _notifications.cancel(notificationId);
    _messageCounts.remove(senderId.toString());
    debugPrint(
        '[NotificationService] Notifications cleared for sender: $senderId');
  }

  /// Cancel a specific notification
  Future<void> cancel(int notificationId) async {
    await _notifications.cancel(notificationId);
  }

  /// Get message type emoji
  String _getMessageTypeEmoji(String? messageType) {
    switch (messageType) {
      case 'urgent':
        return '🚨';
      case 'important':
        return '⚠️';
      case 'info':
        return 'ℹ️';
      default:
        return '';
    }
  }

  /// Reset message counts (call when user opens the app)
  void resetMessageCounts() {
    _messageCounts.clear();
  }

  /// Get badge count (total unread messages)
  int getBadgeCount() {
    return _messageCounts.values.fold(0, (sum, count) => sum + count);
  }
}
