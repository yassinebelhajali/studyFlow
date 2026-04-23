import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/data/schedule/local_schedule_repository.dart';
import 'package:studyflow/domain/models/schedule_session.dart';

void main() {
  test('ScheduleSession parses API JSON and serializes back to API shape', () {
    final session = ScheduleSession.fromJson({
      'id': 'wed-web-tp',
      'dayIndex': 2,
      'title': 'TP-Technologies et programmation web',
      'room': 'A-06',
      'teacher': 'Mrs. Senda Laataoui',
      'colorHex': '#0D9488',
      'startTime': '08:30',
      'endTime': '10:00',
    });

    expect(session.category, 'TP');
    expect(session.displayTitle, 'Technologies et programmation web');
    expect(session.start, const Duration(hours: 8, minutes: 30));
    expect(session.end, const Duration(hours: 10));
    expect(session.toJson()['colorHex'], '#0D9488');
  });

  test('ScheduleSession detects same-day overlaps', () {
    final first = ScheduleSession.fromJson({
      'id': 'first',
      'dayIndex': 1,
      'title': 'TP-First',
      'room': 'A-01',
      'teacher': 'Teacher',
      'colorHex': '#2563EB',
      'startTime': '08:30',
      'endTime': '10:00',
    });
    final second = ScheduleSession.fromJson({
      'id': 'second',
      'dayIndex': 1,
      'title': 'TP-Second',
      'room': 'A-02',
      'teacher': 'Teacher',
      'colorHex': '#16A34A',
      'startTime': '09:30',
      'endTime': '11:00',
    });

    expect(first.overlaps(second), isTrue);
    expect(second.overlaps(first), isTrue);
  });

  test(
    'LocalScheduleRepository returns sessions sorted by day and time',
    () async {
      const repository = LocalScheduleRepository();

      final sessions = await repository.getWeeklySchedule();

      expect(sessions, isNotEmpty);
      for (var index = 1; index < sessions.length; index++) {
        final previous = sessions[index - 1];
        final current = sessions[index];
        final correctlySorted =
            previous.dayIndex < current.dayIndex ||
            previous.dayIndex == current.dayIndex &&
                previous.start <= current.start;
        expect(correctlySorted, isTrue);
      }
    },
  );
}
