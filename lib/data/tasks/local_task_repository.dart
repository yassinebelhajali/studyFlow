import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/study_task.dart';

class LocalTaskRepository {
  LocalTaskRepository(this._preferences);

  static const _storageKey = 'studyflow.tasks.v1';

  final SharedPreferences _preferences;

  Future<List<StudyTask>> getTasks() async {
    final encoded = _preferences.getString(_storageKey);
    if (encoded == null || encoded.trim().isEmpty) {
      final tasks = _seedTasks();
      await saveTasks(tasks);
      return tasks;
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) {
        throw const FormatException('Tasks payload must be a list');
      }
      return decoded
          .map(
            (item) =>
                StudyTask.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList(growable: true);
    } catch (_) {
      final tasks = _seedTasks();
      await saveTasks(tasks);
      return tasks;
    }
  }

  Future<void> saveTasks(List<StudyTask> tasks) async {
    final encoded = jsonEncode(tasks.map((task) => task.toJson()).toList());
    await _preferences.setString(_storageKey, encoded);
  }

  static String createTaskId() {
    return 'task-${DateTime.now().microsecondsSinceEpoch}';
  }

  static List<StudyTask> _seedTasks() {
    return [
      StudyTask(
        id: 'seed-task-1',
        title: 'Tp2',
        dueAt: DateTime(2026, 2, 8, 18),
        subject: 'Entrepots de donnees',
        completed: false,
      ),
      StudyTask(
        id: 'seed-task-2',
        title: 'Chapter 5',
        dueAt: DateTime(2026, 2, 10, 18),
        subject: 'Technologies et programmation web',
        completed: false,
      ),
      StudyTask(
        id: 'seed-task-3',
        title: 'Tp1',
        dueAt: DateTime(2026, 2, 12, 18),
        subject: 'Digital Business Transformation',
        completed: true,
      ),
      StudyTask(
        id: 'seed-task-4',
        title: 'Report',
        dueAt: DateTime(2026, 2, 7, 18),
        subject: 'IT Law, Data Protection and Ethics',
        completed: true,
      ),
      StudyTask(
        id: 'seed-task-5',
        title: 'Report',
        dueAt: DateTime(2026, 2, 7, 18),
        subject: 'Software Testing',
        completed: true,
      ),
      StudyTask(
        id: 'seed-task-6',
        title: 'Chapter 2',
        dueAt: DateTime(2026, 2, 7, 18),
        subject: 'Business Intelligence and Data Analytics',
        completed: true,
      ),
    ];
  }
}
