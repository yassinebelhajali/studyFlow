import '../models/course.dart';

abstract class CourseRepository {
  Future<List<Course>> getCourses();
}
