import 'package:flutter/material.dart';

import '../../../core/notifications/study_notification_scheduler.dart';
import '../../../data/notifications/local_notification_settings_store.dart';
import '../../../data/profile/local_profile_repository.dart';
import '../../../data/tasks/local_task_repository.dart';
import '../../../domain/models/app_user.dart';
import '../../../domain/models/notification_settings.dart';
import '../../../domain/models/profile_identity.dart';
import '../../../domain/models/profile_settings.dart';
import '../../../domain/repositories/schedule_repository.dart';
import '../../../shared/app_theme.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({
    required LocalProfileRepository profileRepository,
    required LocalNotificationSettingsStore notificationSettingsStore,
    required StudyNotificationScheduler notificationScheduler,
    required LocalTaskRepository taskRepository,
    required ScheduleRepository scheduleRepository,
    required Future<void> Function() onLogout,
    required Future<void> Function({
      required String fullName,
      required String email,
    })
    onAuthProfileUpdated,
    required Future<void> Function({
      required String currentPassword,
      required String newPassword,
    })
    onAuthPasswordChanged,
    required ValueChanged<ThemeMode> onThemeModeChanged,
  }) : _profileRepository = profileRepository,
       _notificationSettingsStore = notificationSettingsStore,
       _notificationScheduler = notificationScheduler,
       _taskRepository = taskRepository,
       _scheduleRepository = scheduleRepository,
       _onLogout = onLogout,
       _onAuthProfileUpdated = onAuthProfileUpdated,
       _onAuthPasswordChanged = onAuthPasswordChanged,
       _onThemeModeChanged = onThemeModeChanged;

  final LocalProfileRepository _profileRepository;
  final LocalNotificationSettingsStore _notificationSettingsStore;
  final StudyNotificationScheduler _notificationScheduler;
  final LocalTaskRepository _taskRepository;
  final ScheduleRepository _scheduleRepository;
  final Future<void> Function() _onLogout;
  final Future<void> Function({required String fullName, required String email})
  _onAuthProfileUpdated;
  final Future<void> Function({
    required String currentPassword,
    required String newPassword,
  })
  _onAuthPasswordChanged;
  final ValueChanged<ThemeMode> _onThemeModeChanged;

  String _activeUserId = 'guest';
  ProfileIdentity _identity = ProfileIdentity.fromUser(null);
  ProfileSettings _settings = ProfileSettings.defaults;
  NotificationSettings _notificationSettings = NotificationSettings.defaults;
  bool _initialized = false;
  bool _isSavingNotifications = false;
  bool _isLoggingOut = false;

  ProfileIdentity get identity => _identity;
  ProfileSettings get settings => _settings;
  NotificationSettings get notificationSettings => _notificationSettings;
  bool get initialized => _initialized;
  bool get isSavingNotifications => _isSavingNotifications;
  bool get isLoggingOut => _isLoggingOut;

  Future<void> initialize(AppUser? user) async {
    final source = ProfileIdentity.fromUser(user);
    _activeUserId = source.userId;

    final storedIdentity = await _profileRepository.loadIdentity(_activeUserId);
    _identity = storedIdentity ?? source;
    _settings = await _profileRepository.loadSettings(_activeUserId);
    _onThemeModeChanged(AppTheme.resolveThemeMode(_settings.themeMode));
    _notificationSettings = _notificationSettingsStore.settings;
    _initialized = true;
    notifyListeners();
  }

  Future<void> updateIdentity({
    required String fullName,
    required String email,
    required String institution,
    required String levelClass,
    String? avatarPath,
  }) async {
    await _onAuthProfileUpdated(fullName: fullName.trim(), email: email.trim());
    _identity = _identity.copyWith(
      fullName: fullName.trim(),
      email: email.trim(),
      institution: institution.trim(),
      levelClass: levelClass.trim(),
      avatarPath: avatarPath,
    );
    await _profileRepository.saveIdentity(_identity);
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _onAuthPasswordChanged(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> updateSettings(ProfileSettings next) async {
    _settings = next;
    await _profileRepository.saveSettings(_activeUserId, next);
    _onThemeModeChanged(AppTheme.resolveThemeMode(next.themeMode));
    notifyListeners();
  }

  Future<void> updateNotificationSettings(NotificationSettings next) async {
    if (_isSavingNotifications) {
      return;
    }

    _isSavingNotifications = true;
    notifyListeners();
    try {
      if (next.notificationsEnabled) {
        await _notificationScheduler.requestPermissions();
      }
      final tasks = await _taskRepository.getTasks();
      final sessions = await _scheduleRepository.getWeeklySchedule();
      await _notificationScheduler.saveSettingsAndSync(
        settings: next,
        tasks: tasks,
        sessions: sessions,
      );
      _notificationSettings = next;
    } finally {
      _isSavingNotifications = false;
      notifyListeners();
    }
  }

  Future<void> sendTestNotification() async {
    await _notificationScheduler.requestPermissions();
    await _notificationScheduler.showDebugNotification();
  }

  Future<void> logout() async {
    if (_isLoggingOut) {
      return;
    }
    _isLoggingOut = true;
    notifyListeners();
    try {
      await _onLogout();
    } finally {
      _isLoggingOut = false;
      notifyListeners();
    }
  }
}
