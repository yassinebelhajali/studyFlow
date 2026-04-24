import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/models/study_task.dart';
import '../../domain/repositories/task_repository.dart';
import 'local_task_repository.dart';

class SupabaseTaskRepository implements TaskRepository {
  SupabaseTaskRepository(
    SharedPreferences preferences, {
    required sb.SupabaseClient client,
  }) : _localCache = LocalTaskRepository(preferences),
       _client = client;

  final LocalTaskRepository _localCache;
  final sb.SupabaseClient _client;

  @override
  Future<List<StudyTask>> getTasks() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return _localCache.getTasks();
    }

    try {
      final rows = await _client
          .from('tasks')
          .select(
            'id, title, subject, due_at, completed, priority, reminder_at',
          )
          .eq('user_id', user.id)
          .order('due_at');

      final tasks = (rows as List<dynamic>)
          .map((row) => _toTask(Map<String, dynamic>.from(row as Map)))
          .toList(growable: true);
      await _localCache.saveTasks(tasks);
      return tasks;
    } on sb.PostgrestException {
      return _localCache.getTasks();
    }
  }

  @override
  Future<void> saveTasks(List<StudyTask> tasks) async {
    await _localCache.saveTasks(tasks);

    final user = _client.auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      if (tasks.isEmpty) {
        await _client.from('tasks').delete().eq('user_id', user.id);
        return;
      }

      final payload = tasks.map((task) => _toRow(task, user.id)).toList();
      await _client.from('tasks').upsert(payload, onConflict: 'id');

      final remoteRows = await _client
          .from('tasks')
          .select('id')
          .eq('user_id', user.id);
      final remoteIds = (remoteRows as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map)['id'] as String)
          .toSet();
      final localIds = tasks.map((task) => task.id).toSet();
      final idsToDelete = remoteIds
          .difference(localIds)
          .toList(growable: false);

      if (idsToDelete.isNotEmpty) {
        await _client.from('tasks').delete().inFilter('id', idsToDelete);
      }
    } on sb.PostgrestException {
      // Keep the local cache as the source of truth when remote sync fails.
    }
  }

  StudyTask _toTask(Map<String, dynamic> row) {
    return StudyTask.fromJson({
      'id': row['id'],
      'title': row['title'],
      'subject': row['subject'],
      'dueAt': row['due_at'],
      'completed': row['completed'] == true,
      'priority': row['priority'],
      'reminderAt': row['reminder_at'],
    });
  }

  Map<String, Object?> _toRow(StudyTask task, String userId) {
    return {
      'id': task.id,
      'user_id': userId,
      'title': task.title,
      'subject': task.subject,
      'due_at': task.dueAt.toUtc().toIso8601String(),
      'completed': task.completed,
      'priority': task.priority.name,
      'reminder_at': task.reminderAt?.toUtc().toIso8601String(),
    };
  }
}
