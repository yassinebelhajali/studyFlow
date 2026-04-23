import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/notification_item.dart';
import '../../domain/repositories/notification_repository.dart';

class LocalNotificationRepository implements NotificationRepository {
  LocalNotificationRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'studyflow_notifications';

  @override
  Future<List<NotificationItem>> getNotifications() async {
    final json = _prefs.getString(_key);
    if (json == null) {
      // Default mock notifications for the first time
      final defaults = [
        const NotificationItem(
          id: '1',
          title: 'Task Due Soon',
          description: 'Math Assignment is due today at 11:59 PM',
          timestamp: '2 hours ago',
          type: NotificationType.taskDue,
          isUnread: true,
        ),
        const NotificationItem(
          id: '2',
          title: 'Class Starting Soon',
          description: 'Advanced Mathematics starts in 45 minutes',
          timestamp: '3 hours ago',
          type: NotificationType.classStarting,
          isUnread: true,
        ),
      ];
      await _save(defaults);
      return defaults;
    }
    final List<dynamic> list = jsonDecode(json);
    return list.map<NotificationItem>((e) => NotificationItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> markAsRead(String id) async {
    final notifications = await getNotifications();
    final index = notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final updated = notifications.map((n) {
        if (n.id == id) {
          return NotificationItem(
            id: n.id,
            title: n.title,
            description: n.description,
            timestamp: n.timestamp,
            type: n.type,
            isUnread: false,
          );
        }
        return n;
      }).toList();
      await _save(updated);
    }
  }

  @override
  Future<void> markAllAsRead() async {
    final notifications = await getNotifications();
    final updated = notifications.map((n) {
      return NotificationItem(
        id: n.id,
        title: n.title,
        description: n.description,
        timestamp: n.timestamp,
        type: n.type,
        isUnread: false,
      );
    }).toList();
    await _save(updated);
  }

  Future<void> _save(List<NotificationItem> list) async {
    final json = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_key, json);
  }
}
