import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/study_task.dart';
import '../auth/local_auth_data_source.dart';
import 'local_task_repository.dart';

class ApiTaskRepository extends LocalTaskRepository {
  ApiTaskRepository(
    super.preferences, {
    required this.baseUrl,
    required this.authSessionStore,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final LocalAuthDataSource authSessionStore;
  final http.Client _client;

  @override
  Future<List<StudyTask>> getTasks() async {
    final userId = authSessionStore.getCurrentUserId();
    if (userId == null) {
      return super.getTasks();
    }

    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/tasks?userId=${Uri.encodeComponent(userId)}'),
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return super.getTasks();
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return super.getTasks();
      }

      final apiTasks = decoded
          .map((item) => StudyTask.fromJson(Map<String, Object?>.from(item as Map)))
          .toList();

      // Merge with local tasks to avoid losing data
      final localTasks = await super.getTasks();
      final mergedIds = <String>{...apiTasks.map((t) => t.id)};
      final result = [...apiTasks];
      
      for (final localTask in localTasks) {
        if (!mergedIds.contains(localTask.id)) {
          result.add(localTask);
          // Try to upload local task to backend in background
          unawaited(saveTasks([localTask]));
        }
      }

      return result;
    } catch (_) {
      return super.getTasks();
    }
  }

  @override
  Future<void> saveTasks(List<StudyTask> tasks) async {
    // Always save locally first
    await super.saveTasks(tasks);

    final userId = authSessionStore.getCurrentUserId();
    if (userId == null) return;

    try {
      for (final task in tasks) {
        await _client.post(
          Uri.parse('$baseUrl/api/tasks'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            ...task.toJson(),
            'userId': userId,
          }),
        ).timeout(const Duration(seconds: 3));
      }
    } catch (_) {
      // Ignore errors for background sync
    }
  }
}

void unawaited(Future<void> future) {}
