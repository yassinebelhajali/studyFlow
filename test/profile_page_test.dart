import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyflow/core/notifications/local_notification_service.dart';
import 'package:studyflow/core/notifications/notification_permission_handler.dart';
import 'package:studyflow/core/notifications/study_notification_scheduler.dart';
import 'package:studyflow/data/notifications/local_notification_settings_store.dart';
import 'package:studyflow/data/notifications/local_notification_repository.dart';
import 'package:studyflow/data/profile/local_profile_repository.dart';
import 'package:studyflow/data/schedule/local_schedule_repository.dart';
import 'package:studyflow/data/tasks/local_task_repository.dart';
import 'package:studyflow/domain/models/app_user.dart';
import 'package:studyflow/core/navigation/app_routes.dart';
import 'package:studyflow/features/profile/presentation/profile_controller.dart';
import 'package:studyflow/features/profile/presentation/profile_page.dart';
import 'package:studyflow/features/profile/presentation/profile_settings_page.dart';

void main() {
  testWidgets('profile page shows all main actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 980));
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final notificationStore = LocalNotificationSettingsStore(preferences);
    await notificationStore.load();
    final scheduler = StudyNotificationScheduler(
      notificationService: LocalNotificationService(
        plugin: FlutterLocalNotificationsPlugin(),
      ),
      permissionHandler: NotificationPermissionHandler(
        FlutterLocalNotificationsPlugin(),
      ),
      settingsStore: notificationStore,
    );

    final controller = ProfileController(
      profileRepository: LocalProfileRepository(preferences),
      notificationSettingsStore: notificationStore,
      notificationScheduler: scheduler,
      taskRepository: LocalTaskRepository(preferences),
      scheduleRepository: const LocalScheduleRepository(),
      onLogout: () async {},
      onAuthProfileUpdated: ({required fullName, required email}) async {},
      onAuthPasswordChanged:
          ({required currentPassword, required newPassword}) async {},
      onThemeModeChanged: (_) {},
    );

    await controller.initialize(
      const AppUser(
        id: 'user-1',
        fullName: 'Study User',
        email: 'user@studyflow.app',
        cin: '12345678',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          controller: controller,
          notificationRepository: LocalNotificationRepository(preferences),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('settings language updates after save', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 980));
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final notificationStore = LocalNotificationSettingsStore(preferences);
    await notificationStore.load();
    final scheduler = StudyNotificationScheduler(
      notificationService: LocalNotificationService(
        plugin: FlutterLocalNotificationsPlugin(),
      ),
      permissionHandler: NotificationPermissionHandler(
        FlutterLocalNotificationsPlugin(),
      ),
      settingsStore: notificationStore,
    );

    final controller = ProfileController(
      profileRepository: LocalProfileRepository(preferences),
      notificationSettingsStore: notificationStore,
      notificationScheduler: scheduler,
      taskRepository: LocalTaskRepository(preferences),
      scheduleRepository: const LocalScheduleRepository(),
      onLogout: () async {},
      onAuthProfileUpdated: ({required fullName, required email}) async {},
      onAuthPasswordChanged:
          ({required currentPassword, required newPassword}) async {},
      onThemeModeChanged: (_) {},
    );

    await controller.initialize(
      const AppUser(
        id: 'user-1',
        fullName: 'Study User',
        email: 'user@studyflow.app',
        cin: '12345678',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: ProfileSettingsPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);

    await controller.updateSettings(
      controller.settings.copyWith(language: 'French'),
    );
    await tester.pumpAndSettle();

    expect(find.text('French'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('logout navigates to login route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 980));
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final notificationStore = LocalNotificationSettingsStore(preferences);
    await notificationStore.load();
    final scheduler = StudyNotificationScheduler(
      notificationService: LocalNotificationService(
        plugin: FlutterLocalNotificationsPlugin(),
      ),
      permissionHandler: NotificationPermissionHandler(
        FlutterLocalNotificationsPlugin(),
      ),
      settingsStore: notificationStore,
    );

    final controller = ProfileController(
      profileRepository: LocalProfileRepository(preferences),
      notificationSettingsStore: notificationStore,
      notificationScheduler: scheduler,
      taskRepository: LocalTaskRepository(preferences),
      scheduleRepository: const LocalScheduleRepository(),
      onLogout: () async {},
      onAuthProfileUpdated: ({required fullName, required email}) async {},
      onAuthPasswordChanged:
          ({required currentPassword, required newPassword}) async {},
      onThemeModeChanged: (_) {},
    );

    await controller.initialize(
      const AppUser(
        id: 'user-1',
        fullName: 'Study User',
        email: 'user@studyflow.app',
        cin: '12345678',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.login: (_) =>
              const Scaffold(body: Center(child: Text('Login Screen'))),
        },
        home: ProfilePage(
          controller: controller,
          notificationRepository: LocalNotificationRepository(preferences),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
    await tester.pumpAndSettle();

    final alertDialog = find.byType(AlertDialog);
    final confirmLogoutButton = find.descendant(
      of: alertDialog,
      matching: find.byType(FilledButton),
    );
    await tester.tap(confirmLogoutButton);
    await tester.pumpAndSettle();

    expect(find.text('Login Screen'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
