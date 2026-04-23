import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

enum StudyNotificationChannel {
  task(
    id: 'studyflow_task_reminders',
    name: 'Task reminders',
    description: 'Notifications for StudyFlow task reminders.',
  ),
  schedule(
    id: 'studyflow_class_reminders',
    name: 'Class reminders',
    description: 'Notifications before scheduled classes.',
  ),
  daily(
    id: 'studyflow_daily_study',
    name: 'Daily study reminder',
    description: 'Daily StudyFlow study reminder.',
  ),
  debug(
    id: 'studyflow_debug',
    name: 'Debug notifications',
    description: 'Test notifications used while configuring StudyFlow.',
  );

  const StudyNotificationChannel({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;
}

class LocalNotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }

    await _configureTimezone();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await plugin.initialize(settings: initializationSettings);
    await _createAndroidChannels();
    _initialized = true;
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required StudyNotificationChannel channel,
    String? payload,
  }) async {
    await initialize();
    await plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _detailsFor(channel),
      payload: payload,
    );
  }

  Future<bool> scheduleOneTime({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required StudyNotificationChannel channel,
    String? payload,
  }) async {
    await initialize();
    await cancel(id);

    if (!scheduledAt.isAfter(DateTime.now())) {
      return false;
    }

    await _zonedScheduleWithFallback(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      channel: channel,
      payload: payload,
    );
    return true;
  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required StudyNotificationChannel channel,
    String? payload,
  }) async {
    await initialize();
    await cancel(id);

    var scheduled = tz.TZDateTime(
      tz.local,
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _zonedScheduleWithFallback(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      channel: channel,
      payload: payload,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<bool> scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int weekday,
    required int hour,
    required int minute,
    required StudyNotificationChannel channel,
    String? payload,
  }) async {
    await initialize();
    await cancel(id);

    final scheduled = _nextWeekdayInstance(
      weekday: weekday,
      hour: hour,
      minute: minute,
    );

    await _zonedScheduleWithFallback(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      channel: channel,
      payload: payload,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
    return true;
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) {
      return;
    }
    await plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) {
      return;
    }
    await plugin.cancelAll();
  }

  Future<void> _zonedScheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required StudyNotificationChannel channel,
    required String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      await plugin.zonedSchedule(
        id: id,
        scheduledDate: scheduledDate,
        notificationDetails: _detailsFor(channel),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: title,
        body: body,
        payload: payload,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } on PlatformException catch (error) {
      if (error.code != 'exact_alarms_not_permitted') {
        rethrow;
      }
      await plugin.zonedSchedule(
        id: id,
        scheduledDate: scheduledDate,
        notificationDetails: _detailsFor(channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
        payload: payload,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    }
  }

  NotificationDetails _detailsFor(StudyNotificationChannel channel) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<void> _createAndroidChannels() async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return;
    }

    for (final channel in StudyNotificationChannel.values) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          channel.id,
          channel.name,
          description: channel.description,
          importance: Importance.high,
        ),
      );
    }
  }

  Future<void> _configureTimezone() async {
    timezone_data.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  tz.TZDateTime _nextWeekdayInstance({
    required int weekday,
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    final daysUntilTarget =
        (weekday - scheduled.weekday) % DateTime.daysPerWeek;
    scheduled = scheduled.add(Duration(days: daysUntilTarget));
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: DateTime.daysPerWeek));
    }
    return scheduled;
  }
}
