import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/navigation/app_transitions.dart';
import 'edit_profile_page.dart';
import 'help_support_page.dart';
import 'notifications_page.dart';
import 'profile_controller.dart';
import 'profile_settings_page.dart';
import '../../../domain/repositories/notification_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.controller,
    required this.notificationRepository,
  });

  final ProfileController controller;
  final NotificationRepository notificationRepository;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _headerGradient = [Color(0xFF6366F1), Color(0xFFA855F7)];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final identity = widget.controller.identity;
        final avatarImage = _avatarImageProvider(identity.avatarPath);
        final initials = _resolveInitials(identity.fullName);

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      Container(
                        height: 230,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: _headerGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundImage: avatarImage,
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white,
                              child: avatarImage == null
                                  ? Text(
                                      initials,
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              identity.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              identity.email,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _StatCard(
                              icon: Icons.menu_book,
                              value: '10',
                              label: 'Courses',
                              color: Colors.blue,
                            ),
                            _StatCard(
                              icon: Icons.calendar_today,
                              value: '94%',
                              label: 'Attendance',
                              color: Colors.green,
                            ),
                            _StatCard(
                              icon: Icons.school,
                              value: '3.8',
                              label: 'GPA',
                              color: Colors.purple,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
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
                              _MenuItem(
                                icon: Icons.edit,
                                text: 'Edit Profile',
                                onTap: () => _openPage(
                                  EditProfilePage(
                                    controller: widget.controller,
                                  ),
                                ),
                              ),
                              _MenuItem(
                                icon: Icons.notifications_none_rounded,
                                text: 'Notifications',
                                onTap: () => _openPage(
                                  NotificationsPage(
                                    controller: widget.controller,
                                    repository: widget.notificationRepository,
                                  ),
                                ),
                              ),
                              _MenuItem(
                                icon: Icons.settings,
                                text: 'Settings',
                                onTap: () => _openPage(
                                  ProfileSettingsPage(
                                    controller: widget.controller,
                                  ),
                                ),
                              ),
                              _MenuItem(
                                icon: Icons.help_outline,
                                text: 'Help & Support',
                                onTap: () => _openPage(const HelpSupportPage()),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: widget.controller.isLoggingOut
                                ? null
                                : _confirmLogout,
                            icon: widget.controller.isLoggingOut
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.logout),
                            label: Text(
                              widget.controller.isLoggingOut
                                  ? 'Logging out...'
                                  : 'Logout',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  ImageProvider<Object>? _avatarImageProvider(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) return null;
    if (avatarPath.startsWith('data:image/')) {
      final commaIndex = avatarPath.indexOf(',');
      if (commaIndex != -1 && commaIndex < avatarPath.length - 1) {
        final rawBase64 = avatarPath.substring(commaIndex + 1);
        try {
          return MemoryImage(base64Decode(rawBase64));
        } catch (_) {
          return null;
        }
      }
      return null;
    }
    if (avatarPath.startsWith('http://') || avatarPath.startsWith('https://')) {
      return NetworkImage(avatarPath);
    }
    return AssetImage(avatarPath);
  }

  String _resolveInitials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'SF';
    }
    final first = parts.first[0].toUpperCase();
    if (parts.length == 1) {
      return first;
    }
    final second = parts.last[0].toUpperCase();
    return '$first$second';
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to logout from StudyFlow?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    await widget.controller.logout();

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(
      AppTransitions.route<void>(
        style: AppTransitionStyle.sharedAxisHorizontal,
        page: page,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
