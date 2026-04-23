enum TaskPriority {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case TaskPriority.low:
        return 'low';
      case TaskPriority.medium:
        return 'medium';
      case TaskPriority.high:
        return 'high';
    }
  }
}

class StudyTask {
  const StudyTask({
    required this.id,
    required this.title,
    required this.dueAt,
    required this.subject,
    required this.completed,
    this.priority = TaskPriority.medium,
    this.reminderAt,
  });

  final String id;
  final String title;
  final DateTime dueAt;
  final String subject;
  final bool completed;
  final TaskPriority priority;
  final DateTime? reminderAt;

  StudyTask copyWith({
    String? id,
    String? title,
    DateTime? dueAt,
    String? subject,
    bool? completed,
    TaskPriority? priority,
    DateTime? reminderAt,
    bool clearReminder = false,
  }) {
    return StudyTask(
      id: id ?? this.id,
      title: title ?? this.title,
      dueAt: dueAt ?? this.dueAt,
      subject: subject ?? this.subject,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      reminderAt: clearReminder ? null : reminderAt ?? this.reminderAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'dueAt': dueAt.toIso8601String(),
      'subject': subject,
      'completed': completed,
      'priority': priority.name,
      'reminderAt': reminderAt?.toIso8601String(),
    };
  }

  factory StudyTask.fromJson(Map<String, Object?> json) {
    return StudyTask(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      dueAt: _requiredDateTime(json, 'dueAt'),
      subject: _requiredString(json, 'subject'),
      completed: json['completed'] == true,
      priority: _parsePriority(json['priority'] as String?),
      reminderAt: _optionalDateTime(json['reminderAt']),
    );
  }

  static TaskPriority _parsePriority(String? name) {
    if (name == null) return TaskPriority.medium;
    return TaskPriority.values.firstWhere(
      (p) => p.name == name,
      orElse: () => TaskPriority.medium,
    );
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw FormatException('Missing string field "$key"');
  }

  static DateTime _requiredDateTime(Map<String, Object?> json, String key) {
    final value = _optionalDateTime(json[key]);
    if (value == null) {
      throw FormatException('Missing datetime field "$key"');
    }
    return value;
  }

  static DateTime? _optionalDateTime(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
