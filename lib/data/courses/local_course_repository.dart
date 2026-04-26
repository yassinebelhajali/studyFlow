import '../../domain/models/course.dart';
import '../../domain/repositories/course_repository.dart';

class LocalCourseRepository implements CourseRepository {
  const LocalCourseRepository();

  @override
  Future<List<Course>> getCourses() async {
    // Return empty list as fallback - no local storage for courses
    return const [];
  }
}
