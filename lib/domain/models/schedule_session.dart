class ScheduleSession {
  const ScheduleSession({
    required this.id,
    required this.dayIndex,
    required this.title,
    required this.room,
    required this.teacher,
    required this.colorValue,
    required this.start,
    required this.end,
  });

  final String id;
  final int dayIndex;
  final String title;
  final String room;
  final String teacher;
  final int colorValue;
  final Duration start;
  final Duration end;

  String get category {
    final separatorIndex = title.indexOf('-');
    if (separatorIndex <= 0 || separatorIndex > 4) {
      return 'COURSE';
    }
    return title.substring(0, separatorIndex).toUpperCase();
  }

  String get displayTitle {
    final separatorIndex = title.indexOf('-');
    if (separatorIndex <= 0) {
      return title;
    }
    return title.substring(separatorIndex + 1).trim();
  }

  Duration get duration => end - start;

  bool isCurrentAt(DateTime now) {
    if (dayIndex != now.weekday - 1) {
      return false;
    }
    final nowMinutes = Duration(hours: now.hour, minutes: now.minute);
    return nowMinutes >= start && nowMinutes < end;
  }

  bool startsAfter(DateTime now) {
    if (dayIndex != now.weekday - 1) {
      return false;
    }
    final nowMinutes = Duration(hours: now.hour, minutes: now.minute);
    return start > nowMinutes;
  }

  bool overlaps(ScheduleSession other) {
    if (dayIndex != other.dayIndex || id == other.id) {
      return false;
    }
    return start < other.end && other.start < end;
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'dayIndex': dayIndex,
      'title': title,
      'room': room,
      'teacher': teacher,
      'colorHex': _formatColor(colorValue),
      'startTime': _formatTime(start),
      'endTime': _formatTime(end),
    };
  }

  factory ScheduleSession.fromJson(Map<String, Object?> json) {
    return ScheduleSession(
      id: _requiredString(json, 'id'),
      dayIndex: _requiredInt(json, 'dayIndex'),
      title: _requiredString(json, 'title'),
      room: _requiredString(json, 'room'),
      teacher: _requiredString(json, 'teacher'),
      colorValue: _parseColor(json['colorHex'] ?? json['colorValue']),
      start: _parseTime(_requiredString(json, 'startTime')),
      end: _parseTime(_requiredString(json, 'endTime')),
    );
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw FormatException('Missing string field "$key"');
  }

  static int _requiredInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    throw FormatException('Missing int field "$key"');
  }

  static Duration _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      throw FormatException('Invalid time "$value"');
    }
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw FormatException('Invalid time "$value"');
    }
    return Duration(hours: hour, minutes: minute);
  }

  static int _parseColor(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is! String) {
      throw const FormatException('Missing color value');
    }
    final normalized = value.replaceFirst('#', '').trim();
    final argb = normalized.length == 6 ? 'FF$normalized' : normalized;
    if (argb.length != 8) {
      throw FormatException('Invalid color "$value"');
    }
    return int.parse(argb, radix: 16);
  }

  static String _formatTime(Duration value) {
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  static String _formatColor(int value) {
    return '#${value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }
}
