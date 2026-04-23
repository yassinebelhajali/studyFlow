enum ThemeModePreference { system, light, dark }

class ProfileSettings {
  const ProfileSettings({
    required this.themeMode,
    required this.language,
    required this.compactTaskCards,
    required this.showStudyTips,
    required this.privateProfile,
  });

  final ThemeModePreference themeMode;
  final String language;
  final bool compactTaskCards;
  final bool showStudyTips;
  final bool privateProfile;

  static const defaults = ProfileSettings(
    themeMode: ThemeModePreference.system,
    language: 'English',
    compactTaskCards: false,
    showStudyTips: true,
    privateProfile: false,
  );

  ProfileSettings copyWith({
    ThemeModePreference? themeMode,
    String? language,
    bool? compactTaskCards,
    bool? showStudyTips,
    bool? privateProfile,
  }) {
    return ProfileSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      compactTaskCards: compactTaskCards ?? this.compactTaskCards,
      showStudyTips: showStudyTips ?? this.showStudyTips,
      privateProfile: privateProfile ?? this.privateProfile,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'themeMode': themeMode.name,
      'language': language,
      'compactTaskCards': compactTaskCards,
      'showStudyTips': showStudyTips,
      'privateProfile': privateProfile,
    };
  }

  factory ProfileSettings.fromJson(Map<String, Object?> json) {
    return ProfileSettings(
      themeMode: _themeModeFrom(json['themeMode']),
      language:
          json['language'] is String &&
              (json['language'] as String).trim().isNotEmpty
          ? json['language'] as String
          : defaults.language,
      compactTaskCards: json['compactTaskCards'] is bool
          ? json['compactTaskCards'] as bool
          : defaults.compactTaskCards,
      showStudyTips: json['showStudyTips'] is bool
          ? json['showStudyTips'] as bool
          : defaults.showStudyTips,
      privateProfile: json['privateProfile'] is bool
          ? json['privateProfile'] as bool
          : defaults.privateProfile,
    );
  }

  static ThemeModePreference _themeModeFrom(Object? raw) {
    if (raw is String) {
      for (final candidate in ThemeModePreference.values) {
        if (candidate.name == raw) {
          return candidate;
        }
      }
    }
    return defaults.themeMode;
  }
}
