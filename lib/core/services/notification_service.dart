import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';
import 'secure_storage_service.dart';
import '../../routes/app_router.dart';
import '../../core/constants/route_names.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  AppLogger.debug('Handling a background message: ${message.messageId}', tag: 'FCM');
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _fcmToken;

  /// Android channel for high importance notifications
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // name
    description: 'This channel is used for important notifications.', // description
    importance: Importance.high,
  );

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Future<void> initialize(SecureStorageService secureStorage) async {
    if (_isInitialized) return;

    try {
      // 1. Setup Local Notifications (for foreground notifications)
      await _setupLocalNotifications();

      // 2. Setup Background Handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Setup Foreground Listeners
      _setupForegroundListeners();

      // 4. Check Initial Message (App started from terminated state)
      _checkInitialMessage();

      // 5. Initialize Token Refresh Listener
      _messaging.onTokenRefresh.listen((newToken) async {
        AppLogger.info('FCM Token Refreshed: $newToken', tag: 'FCM');
        _fcmToken = newToken;
        await secureStorage.saveFcmToken(newToken);
      }).onError((err) {
        AppLogger.error('Failed to get FCM token on refresh', tag: 'FCM', error: err);
      });

      _isInitialized = true;
    } catch (e, stack) {
      AppLogger.error('NotificationService init failed', tag: 'FCM', error: e, stackTrace: stack);
    }
  }

  Future<String?> requestPermissionAndGetToken(SecureStorageService secureStorage) async {
    try {
      final status = await Permission.notification.request();
      AppLogger.info('Notification Permission status: $status', tag: 'FCM');

      if (status.isGranted) {
        _fcmToken = await _messaging.getToken();
        if (_fcmToken != null) {
          AppLogger.info('FCM Token:\n$_fcmToken', tag: 'FCM');
          await secureStorage.saveFcmToken(_fcmToken!);
          return _fcmToken;
        }
      } else if (status.isDenied) {
        AppLogger.warning('Notification permission denied by user', tag: 'FCM');
      } else if (status.isPermanentlyDenied) {
        AppLogger.warning('Notification permission permanently denied. Open settings to enable.', tag: 'FCM');
      }
    } catch (e, stack) {
      AppLogger.error('Failed to request permission or get token', tag: 'FCM', error: e, stackTrace: stack);
    }
    return null;
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _handleDeepLink(response.payload!);
        }
      },
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  void _setupForegroundListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AppLogger.debug('Got a message whilst in the foreground!', tag: 'FCM');
      AppLogger.debug('Message data: ${message.data}', tag: 'FCM');

      if (message.notification != null) {
        AppLogger.debug('Message also contained a notification: ${message.notification}', tag: 'FCM');
        
        final notification = message.notification!;
        final android = message.notification?.android;

        if (android != null) {
          _localNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                icon: android.smallIcon ?? '@mipmap/ic_launcher',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
            payload: jsonEncode(message.data),
          );
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      AppLogger.debug('A new onMessageOpenedApp event was published!', tag: 'FCM');
      _handleDeepLink(jsonEncode(message.data));
    });
  }

  Future<void> _checkInitialMessage() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      AppLogger.debug('App opened from terminated state via notification', tag: 'FCM');
      // Delay to allow GoRouter to initialize its state fully.
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleDeepLink(jsonEncode(initialMessage.data));
      });
    }
  }

  void _handleDeepLink(String payload) {
    try {
      final Map<String, dynamic> data = jsonDecode(payload);
      final String? route = data['route'] as String?;
      
      final targetRoute = (route != null && route.isNotEmpty) ? route : RouteNames.dashboard;
      
      AppLogger.info('Notification clicked. Deep linking to: $targetRoute', tag: 'FCM');
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        context.push(targetRoute);
      } else {
        AppLogger.warning('Cannot navigate: rootNavigatorKey context is null or unmounted', tag: 'FCM');
      }
    } catch (e) {
      AppLogger.error('Failed to parse deep link payload: $payload', tag: 'FCM', error: e);
      // Fallback to dashboard
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        context.push(RouteNames.dashboard);
      }
    }
  }

  String? get currentToken => _fcmToken;
}
