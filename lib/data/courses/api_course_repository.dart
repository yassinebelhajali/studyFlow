import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/course.dart';
import '../../domain/repositories/course_repository.dart';

class ApiCourseRepository implements CourseRepository {
  ApiCourseRepository({required this.baseUrl, required this.client});

  final String baseUrl;
  final http.Client client;

  @override
  Future<List<Course>> getCourses() async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/api/courses'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Course.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load courses: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load courses: $e');
    }
  }
}
