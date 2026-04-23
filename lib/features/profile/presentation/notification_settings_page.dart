import 'package:flutter/material.dart';
import '../../../domain/models/notification_settings.dart';
import 'profile_controller.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key, required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settings = controller.notificationSettings;
        final isSaving = controller.isSavingNotifications;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notification Settings'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (isSaving) const LinearProgressIndicator(minHeight: 2),
                    SwitchListTile(
                      title: const Text('All notifications'),
                      subtitle: const Text('Master switch for all reminders'),
                      value: settings.notificationsEnabled,
                      onChanged: isSaving
                          ? null
                          : (value) {
                              _save(
                                context,
                                settings.copyWith(notificationsEnabled: value),
                              );
                            },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Task reminders'),
                      subtitle: const Text('Alerts before task deadlines'),
                      value: settings.taskRemindersEnabled,
                      onChanged: !settings.notificationsEnabled || isSaving
                          ? null
                          : (value) {
                              _save(
                                context,
                                settings.copyWith(taskRemindersEnabled: value),
                              );
                            },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Class reminders'),
                      subtitle: const Text('Weekly class alert notifications'),
                      value: settings.classRemindersEnabled,
                      onChanged: !settings.notificationsEnabled || isSaving
                          ? null
                          : (value) {
                              _save(
                                context,
                                settings.copyWith(classRemindersEnabled: value),
                              );
                            },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Daily study reminders'),
                      subtitle: Text(
                        'Every day at ${_formatClock(settings.dailyStudyTime)}',
                      ),
                      value: settings.dailyStudyReminderEnabled,
                      onChanged: !settings.notificationsEnabled || isSaving
                          ? null
                          : (value) {
                              _save(
                                context,
                                settings.copyWith(
                                  dailyStudyReminderEnabled: value,
                                ),
                              );
                            },
                    ),
                    ListTile(
                      enabled: settings.notificationsEnabled && !isSaving,
                      leading: const Icon(Icons.access_time),
                      title: const Text('Daily reminder time'),
                      subtitle: Text(_formatClock(settings.dailyStudyTime)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickTime(context, settings),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.bolt, color: Colors.orange),
                      title: const Text('Send test notification'),
                      subtitle: const Text(
                        'Check your local notification setup',
                      ),
                      onTap: isSaving
                          ? null
                          : () async {
                              await controller.sendTestNotification();
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Test notification sent.'),
                                ),
                              );
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    NotificationSettings settings,
  ) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.dailyStudyTime.hour,
        minute: settings.dailyStudyTime.minute,
      ),
    );
    if (selected == null || !context.mounted) {
      return;
    }
    await _save(
      context,
      settings.copyWith(
        dailyStudyTime: ReminderClockTime(
          hour: selected.hour,
          minute: selected.minute,
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, NotificationSettings next) async {
    try {
      await controller.updateNotificationSettings(next);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification preferences saved.')),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save notification settings.')),
      );
    }
  }

  String _formatClock(ReminderClockTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
