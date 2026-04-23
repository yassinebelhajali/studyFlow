import '../../domain/models/schedule_session.dart';
import '../../domain/repositories/schedule_repository.dart';
import 'schedule_seed.dart';

class LocalScheduleRepository implements ScheduleRepository {
  const LocalScheduleRepository();

  @override
  Future<List<ScheduleSession>> getWeeklySchedule() async {
    final sessions = [...scheduleSeed]
      ..sort((a, b) {
        final dayComparison = a.dayIndex.compareTo(b.dayIndex);
        if (dayComparison != 0) {
          return dayComparison;
        }
        return a.start.compareTo(b.start);
      });
    return sessions;
  }
}
