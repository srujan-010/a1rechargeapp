import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';
import 'secure_storage_service.dart';
import '../../routes/app_router.dart';
import '../../core/constants/route_names.dart';
import 'device_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.debug('Handling a background message: ${message.messageId}', tag: 'FCM');
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  FirebaseMessaging? _messagingInstance;

  FirebaseMessaging? get _messaging {
    if (kIsWeb) return null;
    try {
      _messagingInstance ??= FirebaseMessaging.instance;
      return _messagingInstance;
    } catch (e) {
      AppLogger.warning('FirebaseMessaging.instance unavailable: $e', tag: 'FCM');
      return null;
    }
  }

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _fcmToken;

  String? get currentToken => _fcmToken;

  /// Android channel for high importance notifications
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  Stream<String> get onTokenRefresh {
    if (kIsWeb || _messaging == null) return const Stream.empty();
    try {
      return _messaging!.onTokenRefresh;
    } catch (_) {
      return const Stream.empty();
    }
  }

  Future<void> initialize(SecureStorageService secureStorage) async {
    if (kIsWeb || _isInitialized) return;

    try {
      // 1. Setup Local Notifications (for foreground notifications)
      await _setupLocalNotifications();

      final messaging = _messaging;
      if (messaging == null) return;

      // 2. Setup Background Handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Setup Foreground Listeners
      _setupForegroundListeners();

      // 4. Check Initial Message (App started from terminated state)
      _checkInitialMessage();

      // 5. Initialize Token Refresh Listener
      messaging.onTokenRefresh.listen((newToken) async {
        AppLogger.info('FCM Token Refreshed: $newToken', tag: 'FCM');
        _fcmToken = newToken;
        await secureStorage.saveFcmToken(newToken);
        await DeviceService.instance.registerDeviceToken(newToken);
      }).onError((err) {
        AppLogger.error('Failed to get FCM token on refresh', tag: 'FCM', error: err);
      });

      _isInitialized = true;
    } catch (e, stack) {
      AppLogger.error('NotificationService init failed', tag: 'FCM', error: e, stackTrace: stack);
    }
  }

  Future<String?> requestPermissionAndGetToken([SecureStorageService? secureStorage]) async {
    if (kIsWeb) return null;
    try {
      final messaging = _messaging;
      if (messaging == null) return null;

      final status = await Permission.notification.request();
      AppLogger.info('Notification Permission status: $status', tag: 'FCM');

      if (status.isGranted) {
        _fcmToken = await messaging.getToken();
        if (_fcmToken != null) {
          AppLogger.info('FCM Token:\n$_fcmToken', tag: 'FCM');
          if (secureStorage != null) {
            await secureStorage.saveFcmToken(_fcmToken!);
          }
          await DeviceService.instance.registerDeviceToken(_fcmToken!);
          return _fcmToken;
        }
      } else if (status.isDenied) {
        AppLogger.warning('Notification permission denied by user', tag: 'FCM');
      } else if (status.isPermanentlyDenied) {
        AppLogger.warning('Notification permission permanently denied. Open settings to enable.', tag: 'FCM');
      }
      return null;
    } catch (e, stack) {
      AppLogger.error('FCM Token retrieval failed safely', tag: 'FCM', error: e, stackTrace: stack);
      return null;
    }
  }

  Future<void> _setupLocalNotifications() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          _handleNotificationPayload(response.payload);
        },
      );

      final androidPlugin = _localNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(_channel);
      }
    } catch (e) {
      AppLogger.error('Local notifications setup failed', tag: 'FCM', error: e);
    }
  }

  void _setupForegroundListeners() {
    final messaging = _messaging;
    if (messaging == null) return;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AppLogger.info('Foreground Message Received: ${message.messageId}', tag: 'FCM');
      _showForegroundNotification(message);
    });
  }

  void _showForegroundNotification(RemoteMessage message) {
    try {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    } catch (e) {
      AppLogger.error('Show foreground notification failed', tag: 'FCM', error: e);
    }
  }

  Future<void> _checkInitialMessage() async {
    try {
      final messaging = _messaging;
      if (messaging == null) return;

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        AppLogger.info('App opened from notification: ${message.messageId}', tag: 'FCM');
        _handleNotificationPayload(jsonEncode(message.data));
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        AppLogger.info('Terminated App opened from notification: ${initialMessage.messageId}', tag: 'FCM');
        _handleNotificationPayload(jsonEncode(initialMessage.data));
      }
    } catch (e) {
      AppLogger.error('Check initial message failed', tag: 'FCM', error: e);
    }
  }

  void _handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final route = data['route'] as String?;
      if (route != null && route.isNotEmpty) {
        AppLogger.info('Navigating from notification payload to: $route', tag: 'FCM');
        rootNavigatorKey.currentContext?.push(route);
      }
    } catch (e) {
      AppLogger.error('Failed to parse notification payload', tag: 'FCM', error: e);
    }
  }
}
