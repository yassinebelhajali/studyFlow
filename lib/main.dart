import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/notifications/local_notification_service.dart';
import 'core/notifications/notification_permission_handler.dart';
import 'core/notifications/study_notification_scheduler.dart';
import 'core/app/study_flow_app.dart';
import 'data/ai/ai_backend_client.dart';
import 'data/ai/ai_memory_store.dart';
import 'data/ai/http_ai_backend_client.dart';
import 'data/ai/mock_ai_backend_client.dart';
import 'data/auth/api_auth_repository.dart';
import 'data/auth/local_auth_data_source.dart';
import 'data/auth/local_auth_repository.dart';
import 'data/notifications/local_notification_settings_store.dart';
import 'data/profile/local_profile_repository.dart';
import 'data/schedule/api_schedule_repository.dart';
import 'data/tasks/api_task_repository.dart';
import 'data/tasks/local_task_repository.dart';
import 'domain/repositories/auth_repository.dart';
import 'data/courses/api_course_repository.dart';
import 'data/notifications/local_notification_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const scheduleApiBaseUrl = String.fromEnvironment(
    'STUDYFLOW_API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
  const configuredAiBackendBaseUrl = String.fromEnvironment(
    'STUDYFLOW_AI_BACKEND_URL',
    defaultValue: '',
  );
  const forceMockAiBackend = bool.fromEnvironment(
    'STUDYFLOW_USE_MOCK_AI',
    defaultValue: false,
  );
  const authApiBaseUrl = String.fromEnvironment(
    'STUDYFLOW_AUTH_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
  final preferences = await SharedPreferences.getInstance();
  final authSessionStore = LocalAuthDataSource(preferences);
  final localAuthRepository = LocalAuthRepository(authSessionStore);
  final authRepository = authApiBaseUrl.trim().isEmpty
      ? localAuthRepository
      : ApiAuthRepository(
          baseUrl: authApiBaseUrl,
          sessionStore: authSessionStore,
          client: http.Client(),
          fallback: localAuthRepository,
        );
  final scheduleRepository = ApiScheduleRepository.withLocalFallback(
    baseUrl: scheduleApiBaseUrl,
  );
  final aiBackendBaseUrl = configuredAiBackendBaseUrl.trim().isEmpty
      ? scheduleApiBaseUrl
      : configuredAiBackendBaseUrl;
  final useMockAiBackend =
      forceMockAiBackend || aiBackendBaseUrl.trim().isEmpty;
  final AiBackendClient aiBackendClient = useMockAiBackend
      ? const MockAiBackendClient()
      : HttpAiBackendClient(baseUrl: aiBackendBaseUrl, client: http.Client());
  final aiMemoryStore = AiMemoryStore(preferences);
  final taskRepository = authApiBaseUrl.trim().isEmpty
      ? LocalTaskRepository(preferences)
      : ApiTaskRepository(
          preferences,
          baseUrl: authApiBaseUrl,
          authSessionStore: authSessionStore,
        );
  final courseRepository = ApiCourseRepository(
    baseUrl: authApiBaseUrl,
    client: http.Client(),
  );
  final notificationRepository = LocalNotificationRepository(preferences);
  final profileRepository = LocalProfileRepository(preferences);
  final notificationService = LocalNotificationService();
  await notificationService.initialize();
  final notificationSettingsStore = LocalNotificationSettingsStore(preferences);
  await notificationSettingsStore.load();
  final notificationScheduler = StudyNotificationScheduler(
    notificationService: notificationService,
    permissionHandler: NotificationPermissionHandler(
      notificationService.plugin,
    ),
    settingsStore: notificationSettingsStore,
  );
  await notificationScheduler.syncDailyStudyReminder();
  final sessionController = SessionController(authRepository);
  await sessionController.restoreSession();

  runApp(
    StudyFlowApp(
      sessionController: sessionController,
      scheduleRepository: scheduleRepository,
      aiBackendClient: aiBackendClient,
      aiMemoryStore: aiMemoryStore,
      isMockAiBackend: useMockAiBackend,
      taskRepository: taskRepository,
      courseRepository: courseRepository,
      notificationRepository: notificationRepository,
      profileRepository: profileRepository,
      notificationSettingsStore: notificationSettingsStore,
      notificationScheduler: notificationScheduler,
    ),
  );
}
