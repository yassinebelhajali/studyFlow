import 'package:flutter/material.dart';

import '../../../domain/models/profile_settings.dart';
import 'profile_controller.dart';

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key, required this.controller});

  final ProfileController controller;

  static const _languages = ['English', 'French', 'Arabic'];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settings = controller.settings;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Appearance',
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: const Text('Theme mode'),
                      subtitle: Text(_themeLabel(settings.themeMode)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SegmentedButton<ThemeModePreference>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeModePreference.system,
                            label: Text('System'),
                          ),
                          ButtonSegment(
                            value: ThemeModePreference.light,
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: ThemeModePreference.dark,
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (selection) {
                          final next = selection.first;
                          controller.updateSettings(
                            settings.copyWith(themeMode: next),
                          );
                          _showInfo(
                            context,
                            'Theme preference saved and applied.',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Language',
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(settings.language),
                    initialValue: settings.language,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.language),
                      labelText: 'App language',
                    ),
                    items: _languages
                        .map(
                          (language) => DropdownMenuItem<String>(
                            value: language,
                            child: Text(language),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      controller.updateSettings(
                        settings.copyWith(language: value),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'App Preferences',
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Compact task cards'),
                      subtitle: const Text(
                        'Smaller task cards in task list screens',
                      ),
                      value: settings.compactTaskCards,
                      onChanged: (value) {
                        controller.updateSettings(
                          settings.copyWith(compactTaskCards: value),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Show study tips'),
                      subtitle: const Text(
                        'Display learning suggestions and tips',
                      ),
                      value: settings.showStudyTips,
                      onChanged: (value) {
                        controller.updateSettings(
                          settings.copyWith(showStudyTips: value),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Private profile mode'),
                      subtitle: const Text(
                        'Hide profile details in screenshots',
                      ),
                      value: settings.privateProfile,
                      onChanged: (value) {
                        controller.updateSettings(
                          settings.copyWith(privateProfile: value),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Privacy & About',
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.shield_outlined),
                      title: const Text('Privacy policy'),
                      subtitle: const Text(
                        'Placeholder until backend policy endpoint is added',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        _showInfo(
                          context,
                          'Privacy policy integration is coming soon. This placeholder is intentional until backend content is available.',
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('About StudyFlow'),
                      subtitle: const Text('Version, legal and support links'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        _showInfo(
                          context,
                          'StudyFlow v1.0.0\nDesigned for focused student productivity.',
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

  void _showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _themeLabel(ThemeModePreference value) {
    switch (value) {
      case ThemeModePreference.system:
        return 'System default';
      case ThemeModePreference.light:
        return 'Light mode';
      case ThemeModePreference.dark:
        return 'Dark mode';
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
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
          child: child,
        ),
      ],
    );
  }
}
