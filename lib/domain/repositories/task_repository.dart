import '../models/study_task.dart';

abstract interface class TaskRepository {
  Future<List<StudyTask>> getTasks();

  Future<void> saveTasks(List<StudyTask> tasks);
}

String createStudyTaskId() {
  return 'task-${DateTime.now().microsecondsSinceEpoch}';
}
