import 'package:flutter/material.dart';

enum NotificationType {
  taskDue,
  classStarting,
  aiSuggestion,
  taskCompleted,
  newCourseMaterial,
}

class NotificationItem {
  final String id;
  final String title;
  final String description;
  final String timestamp;
  final NotificationType type;
  final bool isUnread;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.type,
    this.isUnread = true,
  });

  IconData get icon {
    switch (type) {
      case NotificationType.taskDue:
        return Icons.notifications_none;
      case NotificationType.classStarting:
        return Icons.calendar_today_outlined;
      case NotificationType.aiSuggestion:
        return Icons.auto_awesome_outlined;
      case NotificationType.taskCompleted:
        return Icons.check_circle_outline;
      case NotificationType.newCourseMaterial:
        return Icons.menu_book_outlined;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.taskDue:
        return const Color(0xFFFF4D67);
      case NotificationType.classStarting:
        return const Color(0xFF0096EB);
      case NotificationType.aiSuggestion:
        return const Color(0xFFBD45FF);
      case NotificationType.taskCompleted:
        return const Color(0xFF00C875);
      case NotificationType.newCourseMaterial:
        return const Color(0xFFFF9D00);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'timestamp': timestamp,
      'type': type.name,
      'isUnread': isUnread,
    };
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      timestamp: json['timestamp'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.taskDue,
      ),
      isUnread: json['isUnread'] as bool? ?? true,
    );
  }
}
