import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../utils/logger.dart';

class DeviceService {
  DeviceService._internal();
  static final DeviceService instance = DeviceService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<void> registerDeviceToken(String token) async {
    try {
      String? deviceModel;
      String? deviceManufacturer;
      String? osVersion;
      String? appVersion;

      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = packageInfo.version;

        if (kIsWeb) {
          final webBrowserInfo = await _deviceInfo.webBrowserInfo;
          deviceModel = webBrowserInfo.browserName.name;
          deviceManufacturer = webBrowserInfo.vendor;
          osVersion = webBrowserInfo.appVersion;
        } else if (Platform.isAndroid) {
          final androidInfo = await _deviceInfo.androidInfo;
          deviceModel = androidInfo.model;
          deviceManufacturer = androidInfo.manufacturer;
          osVersion = androidInfo.version.release;
        } else if (Platform.isIOS) {
          final iosInfo = await _deviceInfo.iosInfo;
          deviceModel = iosInfo.model;
          deviceManufacturer = 'Apple';
          osVersion = iosInfo.systemVersion;
        }
      } catch (e) {
        AppLogger.warning('Failed to get device info: $e', tag: 'DeviceService');
      }

      final payload = {
        'token': token,
        'fcmToken': token,
        'deviceModel': deviceModel ?? 'Unknown Model',
        'deviceManufacturer': deviceManufacturer ?? 'Unknown Manufacturer',
        'androidVersion': osVersion ?? 'Unknown OS',
        'appVersion': appVersion ?? 'Unknown App Version',
      };

      AppLogger.info('Sending FCM Token registration to /notifications/register-device', tag: 'DeviceService');
    } catch (e) {
      AppLogger.error('Failed to register device token to backend: $e', tag: 'DeviceService');
    }
  }
}
