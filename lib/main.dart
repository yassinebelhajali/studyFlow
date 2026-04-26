import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
import 'data/auth/supabase_auth_repository.dart';
import 'data/notifications/local_notification_settings_store.dart';
import 'data/profile/local_profile_repository.dart';
import 'data/schedule/api_schedule_repository.dart';
import 'data/tasks/api_task_repository.dart';
import 'data/tasks/local_task_repository.dart';
import 'data/tasks/supabase_task_repository.dart';
import 'domain/repositories/auth_repository.dart';
import 'data/courses/api_course_repository.dart';
import 'data/notifications/local_notification_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const scheduleApiBaseUrl = String.fromEnvironment(
    'STUDYFLOW_API_BASE_URL',
    defaultValue: '',
  );
  const configuredAiBackendBaseUrl = String.fromEnvironment(
    'STUDYFLOW_AI_BACKEND_URL',
    defaultValue: 'http://localhost:3000',
  );
  const forceMockAiBackend = bool.fromEnvironment(
    'STUDYFLOW_USE_MOCK_AI',
    defaultValue: false,
  );
  const authApiBaseUrl = String.fromEnvironment(
    'STUDYFLOW_AUTH_BASE_URL',
    defaultValue: '',
  );
  const supabaseUrlFromEnv = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  const supabaseUrlFromNextPublic = String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_URL',
    defaultValue: '',
  );
  const supabaseAnonKeyFromEnv = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  const supabaseAnonKeyFromNextPublic = String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  const supabasePublishableKeyFromEnv = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );
  const supabasePublishableKeyFromNextPublic = String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  final supabaseUrl = supabaseUrlFromEnv.trim().isNotEmpty
      ? supabaseUrlFromEnv
      : supabaseUrlFromNextPublic;
  final supabaseAnonKey = supabaseAnonKeyFromEnv.trim().isNotEmpty
      ? supabaseAnonKeyFromEnv
      : supabaseAnonKeyFromNextPublic.trim().isNotEmpty
      ? supabaseAnonKeyFromNextPublic
      : supabasePublishableKeyFromEnv.trim().isNotEmpty
      ? supabasePublishableKeyFromEnv
      : supabasePublishableKeyFromNextPublic;
  final supabaseConfigured =
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
  if (supabaseConfigured) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  final preferences = await SharedPreferences.getInstance();
  final authSessionStore = LocalAuthDataSource(preferences);
  final localAuthRepository = LocalAuthRepository(authSessionStore);
  final resolvedScheduleApiBaseUrl = _resolveMobileLoopback(scheduleApiBaseUrl);
  final resolvedAuthApiBaseUrl = _resolveMobileLoopback(
    authApiBaseUrl.trim().isEmpty ? scheduleApiBaseUrl : authApiBaseUrl,
  );
  final supabaseAuthRepo = supabaseConfigured
      ? SupabaseAuthRepository(Supabase.instance.client)
      : null;
  final authRepository =
      supabaseAuthRepo ??
      (resolvedAuthApiBaseUrl.trim().isEmpty
          ? localAuthRepository
          : ApiAuthRepository(
              baseUrl: resolvedAuthApiBaseUrl,
              sessionStore: authSessionStore,
              client: http.Client(),
              fallback: localAuthRepository,
            ));
  final scheduleRepository = ApiScheduleRepository.withLocalFallback(
    baseUrl: resolvedScheduleApiBaseUrl,
  );
  final configuredAiBase = configuredAiBackendBaseUrl.trim().isEmpty
      ? resolvedScheduleApiBaseUrl
      : configuredAiBackendBaseUrl;
  final aiBackendBaseUrl = _resolveMobileLoopback(configuredAiBase);
  final useMockAiBackend =
      forceMockAiBackend || aiBackendBaseUrl.trim().isEmpty;
  final AiBackendClient aiBackendClient = useMockAiBackend
      ? const MockAiBackendClient()
      : HttpAiBackendClient(baseUrl: aiBackendBaseUrl, client: http.Client());
  final aiMemoryStore = AiMemoryStore(preferences);
  final taskRepository = supabaseConfigured
      ? SupabaseTaskRepository(preferences, client: Supabase.instance.client)
      : resolvedAuthApiBaseUrl.trim().isEmpty
      ? LocalTaskRepository(preferences)
      : ApiTaskRepository(
          preferences,
          baseUrl: resolvedAuthApiBaseUrl,
          authSessionStore: authSessionStore,
        );
  final courseRepository = ApiCourseRepository.withLocalFallback(
    baseUrl: resolvedScheduleApiBaseUrl,
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
      onAvatarUpload: supabaseAuthRepo != null
          ? (bytes, mime, userId) =>
                supabaseAuthRepo.uploadAvatar(bytes, mime, userId)
          : null,
    ),
  );
}

String _resolveMobileLoopback(String rawBaseUrl) {
  final trimmed = rawBaseUrl.trim();
  if (trimmed.isEmpty || kIsWeb) {
    return trimmed;
  }

  final parsed = Uri.tryParse(trimmed);
  if (parsed == null || parsed.host.isEmpty) {
    return trimmed;
  }

  final host = parsed.host.toLowerCase();
  final isLoopbackHost = host == 'localhost' || host == '127.0.0.1';
  if (!isLoopbackHost) {
    return trimmed;
  }

  if (Platform.isAndroid) {
    return parsed.replace(host: '10.0.2.2').toString();
  }

  return trimmed;
}
