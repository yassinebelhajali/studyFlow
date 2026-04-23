import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationPermissionHandler {
  NotificationPermissionHandler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) {
      return false;
    }

    final androidGranted =
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        true;

    final iosGranted =
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;

    final macGranted =
        await _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;

    return androidGranted != false &&
        iosGranted != false &&
        macGranted != false;
  }

  Future<bool> requestExactAlarmPermission() async {
    if (kIsWeb) {
      return false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestExactAlarmsPermission() ??
        true;
  }
}
