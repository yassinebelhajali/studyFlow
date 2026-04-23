class ReminderClockTime {
  const ReminderClockTime({required this.hour, required this.minute});

  final int hour;
  final int minute;

  static const defaultStudyTime = ReminderClockTime(hour: 19, minute: 0);

  ReminderClockTime copyWith({int? hour, int? minute}) {
    return ReminderClockTime(
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  Map<String, Object?> toJson() {
    return {'hour': hour, 'minute': minute};
  }

  factory ReminderClockTime.fromJson(Map<String, Object?> json) {
    return ReminderClockTime(
      hour: _intInRange(json['hour'], min: 0, max: 23, fallback: 19),
      minute: _intInRange(json['minute'], min: 0, max: 59, fallback: 0),
    );
  }

  static int _intInRange(
    Object? value, {
    required int min,
    required int max,
    required int fallback,
  }) {
    if (value is! int || value < min || value > max) {
      return fallback;
    }
    return value;
  }
}

class NotificationSettings {
  const NotificationSettings({
    required this.notificationsEnabled,
    required this.taskRemindersEnabled,
    required this.classRemindersEnabled,
    required this.dailyStudyReminderEnabled,
    required this.defaultTaskLeadMinutes,
    required this.classLeadMinutes,
    required this.dailyStudyTime,
  });

  final bool notificationsEnabled;
  final bool taskRemindersEnabled;
  final bool classRemindersEnabled;
  final bool dailyStudyReminderEnabled;
  final int defaultTaskLeadMinutes;
  final int classLeadMinutes;
  final ReminderClockTime dailyStudyTime;

  static const supportedLeadMinutes = <int>[10, 15, 30];

  static const defaults = NotificationSettings(
    notificationsEnabled: true,
    taskRemindersEnabled: true,
    classRemindersEnabled: true,
    dailyStudyReminderEnabled: false,
    defaultTaskLeadMinutes: 15,
    classLeadMinutes: 15,
    dailyStudyTime: ReminderClockTime.defaultStudyTime,
  );

  bool get shouldScheduleTasks => notificationsEnabled && taskRemindersEnabled;

  bool get shouldScheduleClasses =>
      notificationsEnabled && classRemindersEnabled;

  bool get shouldScheduleDailyStudy =>
      notificationsEnabled && dailyStudyReminderEnabled;

  NotificationSettings copyWith({
    bool? notificationsEnabled,
    bool? taskRemindersEnabled,
    bool? classRemindersEnabled,
    bool? dailyStudyReminderEnabled,
    int? defaultTaskLeadMinutes,
    int? classLeadMinutes,
    ReminderClockTime? dailyStudyTime,
  }) {
    return NotificationSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      taskRemindersEnabled: taskRemindersEnabled ?? this.taskRemindersEnabled,
      classRemindersEnabled:
          classRemindersEnabled ?? this.classRemindersEnabled,
      dailyStudyReminderEnabled:
          dailyStudyReminderEnabled ?? this.dailyStudyReminderEnabled,
      defaultTaskLeadMinutes: _normalizeLeadMinutes(
        defaultTaskLeadMinutes ?? this.defaultTaskLeadMinutes,
      ),
      classLeadMinutes: _normalizeLeadMinutes(
        classLeadMinutes ?? this.classLeadMinutes,
      ),
      dailyStudyTime: dailyStudyTime ?? this.dailyStudyTime,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'taskRemindersEnabled': taskRemindersEnabled,
      'classRemindersEnabled': classRemindersEnabled,
      'dailyStudyReminderEnabled': dailyStudyReminderEnabled,
      'defaultTaskLeadMinutes': defaultTaskLeadMinutes,
      'classLeadMinutes': classLeadMinutes,
      'dailyStudyTime': dailyStudyTime.toJson(),
    };
  }

  factory NotificationSettings.fromJson(Map<String, Object?> json) {
    return NotificationSettings.defaults.copyWith(
      notificationsEnabled: _boolValue(
        json['notificationsEnabled'],
        NotificationSettings.defaults.notificationsEnabled,
      ),
      taskRemindersEnabled: _boolValue(
        json['taskRemindersEnabled'],
        NotificationSettings.defaults.taskRemindersEnabled,
      ),
      classRemindersEnabled: _boolValue(
        json['classRemindersEnabled'],
        NotificationSettings.defaults.classRemindersEnabled,
      ),
      dailyStudyReminderEnabled: _boolValue(
        json['dailyStudyReminderEnabled'],
        NotificationSettings.defaults.dailyStudyReminderEnabled,
      ),
      defaultTaskLeadMinutes: _normalizeLeadMinutes(
        json['defaultTaskLeadMinutes'],
      ),
      classLeadMinutes: _normalizeLeadMinutes(json['classLeadMinutes']),
      dailyStudyTime: json['dailyStudyTime'] is Map
          ? ReminderClockTime.fromJson(
              Map<String, Object?>.from(json['dailyStudyTime'] as Map),
            )
          : ReminderClockTime.defaultStudyTime,
    );
  }

  static bool _boolValue(Object? value, bool fallback) {
    return value is bool ? value : fallback;
  }

  static int _normalizeLeadMinutes(Object? value) {
    final minutes = value is int ? value : 15;
    return supportedLeadMinutes.contains(minutes) ? minutes : 15;
  }
}
