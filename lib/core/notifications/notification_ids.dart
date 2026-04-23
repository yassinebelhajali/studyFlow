abstract final class NotificationIds {
  static const dailyStudyReminder = 900001;
  static const debugNotification = 900002;

  static int taskReminder(String taskId) {
    return _stableId(taskId, rangeStart: 100000);
  }

  static int classReminder(String sessionId) {
    return _stableId(sessionId, rangeStart: 300000);
  }

  static int _stableId(String value, {required int rangeStart}) {
    var hash = 0x811C9DC5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return rangeStart + (hash % 100000);
  }
}
