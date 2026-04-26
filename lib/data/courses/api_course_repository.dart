import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/course.dart';
import '../../domain/repositories/course_repository.dart';
import 'local_course_repository.dart';

class ApiCourseRepository implements CourseRepository {
  ApiCourseRepository({
    required this.baseUrl,
    required this.client,
    CourseRepository? fallback,
  }) : _fallback = fallback;

  factory ApiCourseRepository.withLocalFallback({required String baseUrl}) {
    return ApiCourseRepository(
      baseUrl: baseUrl,
      client: http.Client(),
      fallback: const LocalCourseRepository(),
    );
  }

  final String baseUrl;
  final http.Client client;
  final CourseRepository? _fallback;

  @override
  Future<List<Course>> getCourses() async {
    try {
      final response = await client
          .get(
            Uri.parse('$baseUrl/api/courses'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Course.fromJson(json)).toList();
      } else {
        if (_fallback != null) {
          return _fallback.getCourses();
        }
        throw Exception('Failed to load courses: ${response.statusCode}');
      }
    } catch (e) {
      if (_fallback != null) {
        return _fallback.getCourses();
      }
      throw Exception('Failed to load courses: $e');
    }
  }
}
