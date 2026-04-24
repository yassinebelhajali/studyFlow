import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../data/ai/ai_backend_client.dart';
import '../../../cours_page.dart';
import '../../../core/notifications/study_notification_scheduler.dart';
import '../../../data/ai/ai_memory_store.dart';
import '../../../data/ai/study_chat_repository.dart';
import '../../../data/notifications/local_notification_settings_store.dart';
import '../../../data/profile/local_profile_repository.dart';
import '../../../core/navigation/app_transitions.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/course_repository.dart';
import '../../../domain/repositories/notification_repository.dart';
import '../../../domain/repositories/schedule_repository.dart';
import '../../../domain/repositories/task_repository.dart';
import '../../../emploi.dart';
import '../../ai/application/ai_tool.dart';
import '../../ai/application/study_tools.dart';
import '../../ai/presentation/chat_controller.dart';
import '../../ai/presentation/chat_page.dart';
import '../../../home.dart';
import '../../../profile.dart';
import '../../../tasks_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({
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
    required this.onThemeModeChanged,
    this.onAvatarUpload,
  });

  final SessionController sessionController;
  final ScheduleRepository scheduleRepository;
  final AiBackendClient aiBackendClient;
  final AiMemoryStore aiMemoryStore;
  final bool isMockAiBackend;
  final TaskRepository taskRepository;
  final CourseRepository courseRepository;
  final NotificationRepository notificationRepository;
  final LocalProfileRepository profileRepository;
  final LocalNotificationSettingsStore notificationSettingsStore;
  final StudyNotificationScheduler notificationScheduler;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Future<String?> Function(Uint8List bytes, String mime, String userId)?
  onAvatarUpload;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _schedulePageResetToken = 0;
  late final ChatController _chatController;
  late final ProfileController _profileController;

  @override
  void initState() {
    super.initState();
    final tools = ToolRegistry([
      TodayScheduleTool(widget.scheduleRepository),
      const StudyPlanningTool(),
      AddTaskTool(widget.taskRepository),
    ]);
    _chatController = ChatController(
      userId: widget.sessionController.currentUser?.id ?? 'anonymous',
      repository: StudyChatRepository(
        memoryStore: widget.aiMemoryStore,
        client: widget.aiBackendClient,
        preferStreaming: const bool.fromEnvironment(
          'STUDYFLOW_AI_STREAMING',
          defaultValue: true,
        ),
      ),
      tools: tools,
    );
    unawaited(_chatController.restore());
    _profileController = ProfileController(
      profileRepository: widget.profileRepository,
      notificationSettingsStore: widget.notificationSettingsStore,
      notificationScheduler: widget.notificationScheduler,
      taskRepository: widget.taskRepository,
      scheduleRepository: widget.scheduleRepository,
      onLogout: widget.sessionController.signOut,
      onThemeModeChanged: widget.onThemeModeChanged,
      onAuthProfileUpdated: ({required fullName, required email}) {
        return widget.sessionController.updateProfile(
          fullName: fullName,
          email: email,
        );
      },
      onAuthPasswordChanged:
          ({required currentPassword, required newPassword}) {
            return widget.sessionController.changePassword(
              currentPassword: currentPassword,
              newPassword: newPassword,
            );
          },
      onAvatarUpload: widget.onAvatarUpload,
    );
    unawaited(
      _profileController.initialize(widget.sessionController.currentUser),
    );
  }

  @override
  void dispose() {
    _chatController.dispose();
    _profileController.dispose();
    super.dispose();
  }

  void _navigateFromHome(String page) {
    const pageIndex = <String, int>{
      'home': 0,
      'emploi': 1,
      'tasks': 2,
      'cours': 3,
      'profile': 4,
    };
    final nextIndex = pageIndex[page] ?? 0;
    setState(() {
      _currentIndex = nextIndex;
      if (nextIndex == 1) {
        _schedulePageResetToken++;
      }
    });
  }

  void _openNotifications() {
    Navigator.of(context).push(
      AppTransitions.route<void>(
        style: AppTransitionStyle.sharedAxisVertical,
        page: NotificationsPage(
          controller: _profileController,
          repository: widget.notificationRepository,
        ),
      ),
    );
  }

  void _openChat([String? initialPrompt]) {
    Navigator.of(context).push(
      AppTransitions.route<void>(
        style: AppTransitionStyle.sharedAxisHorizontal,
        page: ChatPage(
          controller: _chatController,
          isMockBackend: widget.isMockAiBackend,
        ),
      ),
    );

    if (initialPrompt != null && initialPrompt.trim().isNotEmpty) {
      unawaited(_chatController.sendMessage(initialPrompt));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.sessionController.currentUser;
    final pages = <Widget>[
      HomePage(
        userName: user?.fullName ?? 'Student',
        onNavigate: _navigateFromHome,
        onOpenChat: () => _openChat(),
        onStartChatPrompt: _openChat,
        onNotificationTap: _openNotifications,
        scheduleRepository: widget.scheduleRepository,
        taskRepository: widget.taskRepository,
      ),
      SchedulePage(
        key: ValueKey('schedule-$_schedulePageResetToken'),
        repository: widget.scheduleRepository,
        notificationScheduler: widget.notificationScheduler,
      ),
      TasksPage(repository: widget.taskRepository),
      CoursPage(repository: widget.courseRepository),
      ProfilePage(
        controller: _profileController,
        notificationRepository: widget.notificationRepository,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 1) {
              _schedulePageResetToken++;
            }
          });
        },
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Emploi'),
          BottomNavigationBarItem(icon: Icon(Icons.check_box), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Cours'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
