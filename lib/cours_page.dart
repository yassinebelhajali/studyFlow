import 'package:flutter/material.dart';

import 'core/navigation/app_transitions.dart';
import 'domain/models/course.dart';
import 'domain/repositories/course_repository.dart';

class CoursPage extends StatefulWidget {
  const CoursPage({super.key, required this.repository});

  final CourseRepository repository;

  @override
  State<CoursPage> createState() => _CoursPageState();
}

class _CoursPageState extends State<CoursPage> {
  late Future<List<Course>> _coursesFuture;

  @override
  void initState() {
    super.initState();
    _coursesFuture = widget.repository.getCourses();
  }

  Future<void> _refresh() async {
    setState(() {
      _coursesFuture = widget.repository.getCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        toolbarHeight: 90,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded, size: 26),
                SizedBox(width: 10),
                Text(
                  'My Courses',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              'Your academic modules and credits',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<Course>>(
        future: _coursesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 44, color: Colors.red),
                  const SizedBox(height: 10),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final courses = snapshot.data ?? const <Course>[];
          if (courses.isEmpty) {
            return const Center(child: Text('No courses found.'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];
                return _buildCourseBlock(context, course);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCourseBlock(BuildContext context, Course course) {
    final base = Color(course.colorValue);
    final swatch = _toSwatch(base);
    final scheduleText = '${course.sessionsCount} sessions / week';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: swatch[100] ?? base.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: swatch[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${course.sessionsCount} Credits',
              style: TextStyle(fontWeight: FontWeight.bold, color: swatch[900]),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            course.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  course.teacher,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 20),
              const SizedBox(width: 6),
              Text(scheduleText, style: const TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.grey[200]),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                course.room,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    AppTransitions.route<void>(
                      style: AppTransitionStyle.sharedAxisHorizontal,
                      page: CourseDetailsPage(
                        credits: course.sessionsCount,
                        color: swatch,
                        title: course.title,
                        teacher: course.teacher,
                        schedule: scheduleText,
                        room: course.room,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: swatch[100],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 8,
                  ),
                ),
                child: Text('Open', style: TextStyle(color: swatch[900])),
              ),
            ],
          ),
        ],
      ),
    );
  }

  MaterialColor _toSwatch(Color color) {
    final strengths = <double>[0.05];
    const swatchLevels = <int>[50, 100, 200, 300, 400, 500, 600, 700, 800, 900];
    final swatch = <int, Color>{};
    final red = (color.r * 255).round().clamp(0, 255);
    final green = (color.g * 255).round().clamp(0, 255);
    final blue = (color.b * 255).round().clamp(0, 255);

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }

    for (int i = 0; i < strengths.length; i++) {
      final strength = strengths[i];
      final ds = 0.5 - strength;
      swatch[swatchLevels[i]] = Color.fromRGBO(
        red + ((ds < 0 ? red : (255 - red)) * ds).round(),
        green + ((ds < 0 ? green : (255 - green)) * ds).round(),
        blue + ((ds < 0 ? blue : (255 - blue)) * ds).round(),
        1,
      );
    }

    return MaterialColor(color.toARGB32(), swatch);
  }
}

class CourseDetailsPage extends StatelessWidget {
  const CourseDetailsPage({
    super.key,
    required this.credits,
    required this.color,
    required this.title,
    required this.teacher,
    required this.schedule,
    required this.room,
  });

  final int credits;
  final MaterialColor color;
  final String title;
  final String teacher;
  final String schedule;
  final String room;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: color[600],
        foregroundColor: Colors.white,
        title: const Text('Course Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$credits Credits',
                    style: TextStyle(
                      color: color[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _DetailTile(
              icon: Icons.person_outline,
              label: 'Teacher',
              value: teacher,
            ),
            const SizedBox(height: 10),
            _DetailTile(
              icon: Icons.access_time,
              label: 'Schedule',
              value: schedule,
            ),
            const SizedBox(height: 10),
            _DetailTile(
              icon: Icons.location_on_outlined,
              label: 'Room',
              value: room,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
