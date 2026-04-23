import '../models/schedule_session.dart';

abstract interface class ScheduleRepository {
  Future<List<ScheduleSession>> getWeeklySchedule();
}

class ScheduleException implements Exception {
  const ScheduleException(this.message);

  final String message;

  @override
  String toString() => message;
}
