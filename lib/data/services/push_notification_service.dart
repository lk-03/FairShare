import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

/// Service managing background and foreground push notifications via FCM and local notifications
class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static String? _cachedFcmToken;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'fairshare_high_importance',
    'FairShare Activity & Alerts',
    description:
        'Real-time push notifications for new expenses, comments, and house cart needs.',
    importance: Importance.max,
  );

  /// Initializes Firebase Cloud Messaging and local heads-up notification display
  static Future<void> initialize({Function(String? route)? onSelectNotification}) async {
    if (_initialized) return;

    // Firebase only supported on mobile/web platforms
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    try {
      await Firebase.initializeApp();
      _initialized = true;

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 1. Request OS Notification Permissions
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // 2. Set up Android Local Notification Channel
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsDarwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && onSelectNotification != null) {
            onSelectNotification(payload);
          }
        },
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // 3. Foreground Notification Listener: Display Heads-up Banner
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final android = message.notification?.android;

        if (notification != null && !kIsWeb) {
          _localNotifications.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                icon: android?.smallIcon ?? '@mipmap/ic_launcher',
                importance: Importance.max,
                priority: Priority.high,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            payload: message.data['route'] ?? message.data['cohort_id'],
          );
        }
      });

      // 4. Notification tap when app is opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final route = message.data['route'] ??
            (message.data['cohort_id'] != null
                ? '/groups/${message.data['cohort_id']}'
                : '/activity');
        if (onSelectNotification != null) {
          onSelectNotification(route);
        }
      });

      // 5. Check if launched from terminated state via notification
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null && onSelectNotification != null) {
        final route = initialMessage.data['route'] ??
            (initialMessage.data['cohort_id'] != null
                ? '/groups/${initialMessage.data['cohort_id']}'
                : '/activity');
        onSelectNotification(route);
      }
    } catch (e) {
      // In test environments or when Firebase config is absent, proceed gracefully
      debugPrint('[PushNotificationService] Initialization notice: $e');
    }
  }

  /// Syncs the device FCM token with the user profile in Supabase
  static Future<void> syncDeviceToken(String userId) async {
    if (!isUuid(userId) || !_initialized) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token != _cachedFcmToken) {
        _cachedFcmToken = token;
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', userId);
      }

      // Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        _cachedFcmToken = newToken;
        try {
          await Supabase.instance.client
              .from('profiles')
              .update({'fcm_token': newToken})
              .eq('id', userId);
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[PushNotificationService] Could not sync FCM token: $e');
    }
  }

  /// Clears device token upon sign-out
  static Future<void> clearDeviceToken(String userId) async {
    if (!isUuid(userId)) return;
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': null})
          .eq('id', userId);
      _cachedFcmToken = null;
    } catch (_) {}
  }
}
