import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/schedule_session.dart';
import '../../domain/repositories/schedule_repository.dart';
import 'local_schedule_repository.dart';

class ApiScheduleRepository implements ScheduleRepository {
  ApiScheduleRepository({
    required this.baseUrl,
    required http.Client client,
    ScheduleRepository? fallback,
  }) : _client = client,
       _fallback = fallback;

  factory ApiScheduleRepository.withLocalFallback({required String baseUrl}) {
    return ApiScheduleRepository(
      baseUrl: baseUrl,
      client: http.Client(),
      fallback: const LocalScheduleRepository(),
    );
  }

  final String baseUrl;
  final http.Client _client;
  final ScheduleRepository? _fallback;

  @override
  Future<List<ScheduleSession>> getWeeklySchedule() async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/schedule'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw ScheduleException(
          'Schedule API failed with status ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const ScheduleException('Schedule API returned invalid JSON');
      }

      final sessions = decoded
          .map(
            (item) => ScheduleSession.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(growable: false);
      return sessions..sort((a, b) {
        final dayComparison = a.dayIndex.compareTo(b.dayIndex);
        if (dayComparison != 0) {
          return dayComparison;
        }
        return a.start.compareTo(b.start);
      });
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) {
        return fallback.getWeeklySchedule();
      }
      throw const ScheduleException('Unable to load weekly schedule');
    }
  }
}
