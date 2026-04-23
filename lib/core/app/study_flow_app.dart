import 'package:flutter/material.dart';

import '../../data/ai/ai_backend_client.dart';
import '../../data/ai/ai_memory_store.dart';
import '../../core/notifications/study_notification_scheduler.dart';
import '../../data/notifications/local_notification_settings_store.dart';
import '../../data/profile/local_profile_repository.dart';
import '../../data/tasks/local_task_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/course_repository.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/repositories/schedule_repository.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/signup_page.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../../shared/app_theme.dart';
import '../navigation/app_routes.dart';
import '../navigation/app_transitions.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';

class StudyFlowApp extends StatefulWidget {
  const StudyFlowApp({
    super.key,
    required this.sessionController,
    required this.scheduleRepository,
    required this.aiBackendClient,
    required this.aiMemoryStore,
    required this.isMockAiBackend,
    required this.taskRepository,
    required this.courseRepository,
    required this.notificationRepository,
    required this.profileRepository,
    required this.notificationSettingsStore,
    required this.notificationScheduler,
  });

  final SessionController sessionController;
  final ScheduleRepository scheduleRepository;
  final AiBackendClient aiBackendClient;
  final AiMemoryStore aiMemoryStore;
  final bool isMockAiBackend;
  final LocalTaskRepository taskRepository;
  final CourseRepository courseRepository;
  final NotificationRepository notificationRepository;
  final LocalProfileRepository profileRepository;
  final LocalNotificationSettingsStore notificationSettingsStore;
  final StudyNotificationScheduler notificationScheduler;

  @override
  State<StudyFlowApp> createState() => _StudyFlowAppState();
}

class _StudyFlowAppState extends State<StudyFlowApp> {
  ThemeMode _themeMode = ThemeMode.system;

  Widget _buildMainShell() {
    return MainShell(
      sessionController: widget.sessionController,
      scheduleRepository: widget.scheduleRepository,
      aiBackendClient: widget.aiBackendClient,
      aiMemoryStore: widget.aiMemoryStore,
      isMockAiBackend: widget.isMockAiBackend,
      taskRepository: widget.taskRepository,
      courseRepository: widget.courseRepository,
      notificationRepository: widget.notificationRepository,
      profileRepository: widget.profileRepository,
      notificationSettingsStore: widget.notificationSettingsStore,
      notificationScheduler: widget.notificationScheduler,
      onThemeModeChanged: _onThemeModeChanged,
    );
  }

  void _onThemeModeChanged(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.sessionController,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'StudyFlow',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeMode,
          initialRoute: AppRoutes.splash,
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case AppRoutes.splash:
                return AppTransitions.route<void>(
                  settings: settings,
                  page: SplashScreen(sessionController: widget.sessionController),
                );
              case AppRoutes.onboarding:
                return AppTransitions.route<void>(
                  settings: settings,
                  page: const OnboardingScreen(),
                );
              case AppRoutes.login:
                return AppTransitions.route<void>(
                  settings: settings,
                  page: LoginPage(sessionController: widget.sessionController),
                );
              case AppRoutes.signup:
                return AppTransitions.route<void>(
                  settings: settings,
                  style: AppTransitionStyle.sharedAxisHorizontal,
                  page: SignUpPage(sessionController: widget.sessionController),
                );
              case AppRoutes.home:
                return AppTransitions.route<void>(
                  settings: settings,
                  page: _buildMainShell(),
                );
              default:
                return AppTransitions.route<void>(
                  settings: settings,
                  page: SplashScreen(sessionController: widget.sessionController),
                );
            }
          },
        );
      },
    );
  }
}
