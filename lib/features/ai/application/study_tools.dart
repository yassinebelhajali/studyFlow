import '../../../domain/models/study_task.dart';
import '../../../domain/models/ai/tool_result.dart';
import '../../../domain/models/schedule_session.dart';
import '../../../domain/repositories/schedule_repository.dart';
import '../../../domain/repositories/task_repository.dart';
import 'ai_tool.dart';

class TodayScheduleTool implements AiTool {
  const TodayScheduleTool(this._scheduleRepository);

  final ScheduleRepository _scheduleRepository;

  @override
  String get name => 'today_schedule';

  @override
  String get description => 'Reads the student schedule for the current day.';

  @override
  bool canHandle(AiToolContext context) {
    final text = context.userMessage.toLowerCase();
    return text.contains('schedule') ||
        text.contains('class') ||
        text.contains('course') ||
        text.contains('emploi') ||
        text.contains('today') ||
        text.contains('plan my day');
  }

  @override
  Future<ToolResult> execute(AiToolContext context) async {
    final weeklySchedule = await _scheduleRepository.getWeeklySchedule();
    final todayIndex = context.now.weekday - 1;
    final todaySessions =
        weeklySchedule.where((item) => item.dayIndex == todayIndex).toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    if (todaySessions.isEmpty) {
      return const ToolResult(
        toolName: 'today_schedule',
        success: true,
        summary: 'No scheduled classes were found for today.',
        data: {'sessions': <Object?>[]},
      );
    }

    return ToolResult(
      toolName: name,
      success: true,
      summary: todaySessions.map(_formatSession).join('; '),
      data: {
        'sessions': todaySessions
            .map((item) => item.toJson())
            .toList(growable: false),
      },
    );
  }

  String _formatSession(ScheduleSession session) {
    return '${_formatTime(session.start)}-${_formatTime(session.end)} '
        '${session.displayTitle} in ${session.room}';
  }

  String _formatTime(Duration value) {
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}

class StudyPlanningTool implements AiTool {
  const StudyPlanningTool();

  @override
  String get name => 'study_planner';

  @override
  String get description =>
      'Creates deterministic planning context for study, homework, and tasks.';

  @override
  bool canHandle(AiToolContext context) {
    final text = context.userMessage.toLowerCase();
    return text.contains('plan') ||
        text.contains('study') ||
        text.contains('homework') ||
        text.contains('task') ||
        text.contains('organize');
  }

  @override
  Future<ToolResult> execute(AiToolContext context) async {
    return const ToolResult(
      toolName: 'study_planner',
      success: true,
      summary:
          'Recommended planning frame: prioritize urgent deadlines, use 25-minute focus blocks, reserve breaks, and end with a short review.',
      data: {
        'steps': <String>[
          'List deadlines and classes',
          'Pick the top 3 outcomes',
          'Schedule focused blocks',
          'Review and adjust at the end of the day',
        ],
      },
    );
  }
}

class AddTaskTool implements AiTool {
  const AddTaskTool(this._taskRepository);

  final TaskRepository _taskRepository;

  @override
  String get name => 'add_task';

  @override
  String get description => 'Adds a new study task or homework item.';

  @override
  bool canHandle(AiToolContext context) {
    final text = context.userMessage.toLowerCase();
    return text.contains('add') &&
        (text.contains('task') ||
            text.contains('homework') ||
            text.contains('todo'));
  }

  @override
  Future<ToolResult> execute(AiToolContext context) async {
    final input = context.userMessage;
    // In a real LLM scenario, the input would be structured JSON.
    // For this local/mock improvement, we extract a title from the prompt.
    final title = _extractTitle(input);
    final subject = _extractSubject(input);

    final newTask = StudyTask(
      id: createStudyTaskId(),
      title: title,
      subject: subject,
      dueAt: context.now.add(const Duration(days: 1)),
      completed: false,
    );

    final tasks = await _taskRepository.getTasks();
    tasks.add(newTask);
    await _taskRepository.saveTasks(tasks);

    return ToolResult(
      toolName: name,
      success: true,
      summary: 'Task "$title" for "$subject" has been added.',
      data: newTask.toJson(),
    );
  }

  String _extractTitle(String input) {
    if (input.toLowerCase().contains('english')) {
      return 'Learn English';
    }
    final parts = input.split(' ');
    if (parts.length > 2) {
      return parts.sublist(parts.length - 2).join(' ');
    }
    return 'New Task';
  }

  String _extractSubject(String input) {
    if (input.toLowerCase().contains('english')) {
      return 'English Language';
    }
    return 'General Study';
  }
}
