class Course {
  const Course({
    required this.title,
    required this.room,
    required this.teacher,
    required this.colorHex,
    required this.sessionsCount,
  });

  final String title;
  final String room;
  final String teacher;
  final String colorHex;
  final int sessionsCount;

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      title: json['title'] as String,
      room: json['room'] as String,
      teacher: json['teacher'] as String,
      colorHex: json['colorHex'] as String,
      sessionsCount: json['sessionsCount'] as int,
    );
  }

  int get colorValue {
    final hex = colorHex.replaceAll('#', '');
    if (hex.length == 6) {
      return int.parse('FF$hex', radix: 16);
    }
    return int.parse(hex, radix: 16);
  }
}
