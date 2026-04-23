import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyflow/core/notifications/local_notification_service.dart';
import 'package:studyflow/core/notifications/notification_permission_handler.dart';
import 'package:studyflow/core/notifications/study_notification_scheduler.dart';
import 'package:studyflow/data/notifications/local_notification_settings_store.dart';
import 'package:studyflow/data/profile/local_profile_repository.dart';
import 'package:studyflow/data/schedule/local_schedule_repository.dart';
import 'package:studyflow/data/tasks/local_task_repository.dart';
import 'package:studyflow/domain/models/app_user.dart';
import 'package:studyflow/domain/models/profile_settings.dart';
import 'package:studyflow/features/profile/presentation/profile_controller.dart';

void main() {
  Future<ProfileController> buildController({
    required LocalProfileRepository profileRepository,
    required LocalNotificationSettingsStore notificationSettingsStore,
    required LocalTaskRepository taskRepository,
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
    required void Function(ThemeMode mode) onThemeModeChanged,
    required Future<void> Function() onLogout,
  }) async {
    final scheduler = StudyNotificationScheduler(
      notificationService: LocalNotificationService(
        plugin: FlutterLocalNotificationsPlugin(),
      ),
      permissionHandler: NotificationPermissionHandler(
        FlutterLocalNotificationsPlugin(),
      ),
      settingsStore: notificationSettingsStore,
    );

    return ProfileController(
      profileRepository: profileRepository,
      notificationSettingsStore: notificationSettingsStore,
      notificationScheduler: scheduler,
      taskRepository: taskRepository,
      scheduleRepository: const LocalScheduleRepository(),
      onLogout: onLogout,
      onAuthProfileUpdated: onAuthProfileUpdated,
      onAuthPasswordChanged: onAuthPasswordChanged,
      onThemeModeChanged: onThemeModeChanged,
    );
  }

  test('updateIdentity persists data and syncs auth callback', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final profileRepository = LocalProfileRepository(preferences);
    final notificationStore = LocalNotificationSettingsStore(preferences);
    await notificationStore.load();
    final taskRepository = LocalTaskRepository(preferences);
    String? syncedName;
    String? syncedEmail;

    final controller = await buildController(
      profileRepository: profileRepository,
      notificationSettingsStore: notificationStore,
      taskRepository: taskRepository,
      onAuthProfileUpdated: ({required fullName, required email}) async {
        syncedName = fullName;
        syncedEmail = email;
      },
      onAuthPasswordChanged:
          ({required currentPassword, required newPassword}) async {},
      onThemeModeChanged: (_) {},
      onLogout: () async {},
    );

    const user = AppUser(
      id: 'user-1',
      fullName: 'Old Name',
      email: 'old@example.com',
      cin: '12345678',
    );

    await controller.initialize(user);
    await controller.updateIdentity(
      fullName: 'New Name',
      email: 'new@example.com',
      institution: 'University of Technology',
      levelClass: 'Computer Science - Year 3',
      avatarPath: 'images/studyflow.png',
    );

    expect(syncedName, 'New Name');
    expect(syncedEmail, 'new@example.com');
    expect(controller.identity.fullName, 'New Name');
    expect(controller.identity.email, 'new@example.com');
    expect(controller.identity.avatarPath, 'images/studyflow.png');

    final restoredController = await buildController(
      profileRepository: profileRepository,
      notificationSettingsStore: notificationStore,
      taskRepository: taskRepository,
      onAuthProfileUpdated: ({required fullName, required email}) async {},
      onAuthPasswordChanged:
          ({required currentPassword, required newPassword}) async {},
      onThemeModeChanged: (_) {},
      onLogout: () async {},
    );
    await restoredController.initialize(user);
    expect(restoredController.identity.fullName, 'New Name');
    expect(restoredController.identity.email, 'new@example.com');
    expect(restoredController.identity.avatarPath, 'images/studyflow.png');
  });

  test('updateSettings persists and applies theme mode callback', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final profileRepository = LocalProfileRepository(preferences);
    final notificationStore = LocalNotificationSettingsStore(preferences);
    await notificationStore.load();
    final taskRepository = LocalTaskRepository(preferences);

    ThemeMode? appliedTheme;
    final controller = await buildController(
      profileRepository: profileRepository,
      notificationSettingsStore: notificationStore,
      taskRepository: taskRepository,
      onAuthProfileUpdated: ({required fullName, required email}) async {},
      onAuthPasswordChanged:
          ({required currentPassword, required newPassword}) async {},
      onThemeModeChanged: (mode) {
        appliedTheme = mode;
      },
      onLogout: () async {},
    );

    const user = AppUser(
      id: 'user-1',
      fullName: 'Student',
      email: 'student@example.com',
      cin: '12345678',
    );

    await controller.initialize(user);
    await controller.updateSettings(
      controller.settings.copyWith(
        themeMode: ThemeModePreference.dark,
        language: 'French',
      ),
    );

    expect(appliedTheme, ThemeMode.dark);

    final restoredController = await buildController(
      profileRepository: profileRepository,
      notificationSettingsStore: notificationStore,
      taskRepository: taskRepository,
      onAuthProfileUpdated: ({required fullName, required email}) async {},
      onAuthPasswordChanged:
          ({required currentPassword, required newPassword}) async {},
      onThemeModeChanged: (_) {},
      onLogout: () async {},
    );
    await restoredController.initialize(user);
    expect(restoredController.settings.themeMode, ThemeModePreference.dark);
    expect(restoredController.settings.language, 'French');
  });

  test('logout calls callback and resets loading state', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final profileRepository = LocalProfileRepository(preferences);
    final notificationStore = LocalNotificationSettingsStore(preferences);
    await notificationStore.load();
    final taskRepository = LocalTaskRepository(preferences);

    var logoutCalled = false;
    final controller = await buildController(
      profileRepository: profileRepository,
      notificationSettingsStore: notificationStore,
      taskRepository: taskRepository,
      onAuthProfileUpdated: ({required fullName, required email}) async {},
      onAuthPasswordChanged:
          ({required currentPassword, required newPassword}) async {},
      onThemeModeChanged: (_) {},
      onLogout: () async {
        logoutCalled = true;
      },
    );

    await controller.logout();
    expect(logoutCalled, isTrue);
    expect(controller.isLoggingOut, isFalse);
  });

  test('changePassword forwards values to auth callback', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final profileRepository = LocalProfileRepository(preferences);
    final notificationStore = LocalNotificationSettingsStore(preferences);
    await notificationStore.load();
    final taskRepository = LocalTaskRepository(preferences);

    String? receivedCurrent;
    String? receivedNext;
    final controller = await buildController(
      profileRepository: profileRepository,
      notificationSettingsStore: notificationStore,
      taskRepository: taskRepository,
      onAuthProfileUpdated: ({required fullName, required email}) async {},
      onAuthPasswordChanged:
          ({required currentPassword, required newPassword}) async {
            receivedCurrent = currentPassword;
            receivedNext = newPassword;
          },
      onThemeModeChanged: (_) {},
      onLogout: () async {},
    );

    await controller.changePassword(
      currentPassword: 'OldPass123',
      newPassword: 'NewPass123',
    );

    expect(receivedCurrent, 'OldPass123');
    expect(receivedNext, 'NewPass123');
  });
}
