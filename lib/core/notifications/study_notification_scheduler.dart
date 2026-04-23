import '../../data/notifications/local_notification_settings_store.dart';
import '../../domain/models/notification_settings.dart';
import '../../domain/models/schedule_session.dart';
import '../../domain/models/study_task.dart';
import 'local_notification_service.dart';
import 'notification_ids.dart';
import 'notification_permission_handler.dart';

class StudyNotificationScheduler {
  StudyNotificationScheduler({
    required LocalNotificationService notificationService,
    required NotificationPermissionHandler permissionHandler,
    required LocalNotificationSettingsStore settingsStore,
  }) : _notificationService = notificationService,
       _permissionHandler = permissionHandler,
       _settingsStore = settingsStore;

  final LocalNotificationService _notificationService;
  final NotificationPermissionHandler _permissionHandler;
  final LocalNotificationSettingsStore _settingsStore;

  Future<bool> requestPermissions() async {
    await _notificationService.initialize();
    final notificationsGranted = await _permissionHandler
        .requestNotificationPermission();
    await _permissionHandler.requestExactAlarmPermission();
    return notificationsGranted;
  }

  Future<void> syncTaskReminder(StudyTask task) async {
    final settings = await _settingsStore.load();
    final id = NotificationIds.taskReminder(task.id);

    if (!settings.shouldScheduleTasks ||
        task.completed ||
        task.reminderAt == null) {
      await _notificationService.cancel(id);
      return;
    }

    await _notificationService.scheduleOneTime(
      id: id,
      title: 'Task reminder: ${task.title}',
      body: '${task.subject} is due ${_formatDateTime(task.dueAt)}.',
      scheduledAt: task.reminderAt!,
      channel: StudyNotificationChannel.task,
      payload: 'task:${task.id}',
    );
  }

  Future<void> cancelTaskReminder(String taskId) async {
    await _notificationService.cancel(NotificationIds.taskReminder(taskId));
  }

  Future<void> syncAllTaskReminders(List<StudyTask> tasks) async {
    for (final task in tasks) {
      await syncTaskReminder(task);
    }
  }

  Future<void> syncClassReminders(List<ScheduleSession> sessions) async {
    final settings = await _settingsStore.load();
    for (final session in sessions) {
      final id = NotificationIds.classReminder(session.id);
      await _notificationService.cancel(id);

      if (!settings.shouldScheduleClasses) {
        continue;
      }

      final reminderStart =
          session.start - Duration(minutes: settings.classLeadMinutes);
      if (reminderStart.isNegative) {
        continue;
      }

      await _notificationService.scheduleWeekly(
        id: id,
        title: 'Upcoming class: ${session.displayTitle}',
        body:
            '${session.room} with ${session.teacher} starts in ${settings.classLeadMinutes} minutes.',
        weekday: session.dayIndex + 1,
        hour: reminderStart.inHours,
        minute: reminderStart.inMinutes % 60,
        channel: StudyNotificationChannel.schedule,
        payload: 'class:${session.id}',
      );
    }
  }

  Future<void> cancelClassReminders(List<ScheduleSession> sessions) async {
    for (final session in sessions) {
      await _notificationService.cancel(
        NotificationIds.classReminder(session.id),
      );
    }
  }

  Future<void> syncDailyStudyReminder() async {
    final settings = await _settingsStore.load();
    if (!settings.shouldScheduleDailyStudy) {
      await _notificationService.cancel(NotificationIds.dailyStudyReminder);
      return;
    }

    await _notificationService.scheduleDaily(
      id: NotificationIds.dailyStudyReminder,
      title: 'Study reminder',
      body: 'Time to review your tasks and classes for today.',
      hour: settings.dailyStudyTime.hour,
      minute: settings.dailyStudyTime.minute,
      channel: StudyNotificationChannel.daily,
      payload: 'daily-study',
    );
  }

  Future<void> syncAll({
    required List<StudyTask> tasks,
    required List<ScheduleSession> sessions,
  }) async {
    await syncAllTaskReminders(tasks);
    await syncClassReminders(sessions);
    await syncDailyStudyReminder();
  }

  Future<void> saveSettingsAndSync({
    required NotificationSettings settings,
    required List<StudyTask> tasks,
    required List<ScheduleSession> sessions,
  }) async {
    await _settingsStore.save(settings);
    await syncAll(tasks: tasks, sessions: sessions);
  }

  Future<void> showDebugNotification() async {
    await _notificationService.showNow(
      id: NotificationIds.debugNotification,
      title: 'StudyFlow notifications are ready',
      body: 'This is a local test notification.',
      channel: StudyNotificationChannel.debug,
      payload: 'debug',
    );
  }

  String _formatDateTime(DateTime value) {
    final date =
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date at $time';
  }
}
