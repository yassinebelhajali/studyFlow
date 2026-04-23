import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/profile_identity.dart';
import '../../domain/models/profile_settings.dart';

class LocalProfileRepository {
  LocalProfileRepository(this._preferences);

  static const _profilePrefix = 'studyflow.profile.identity.v1.';
  static const _settingsPrefix = 'studyflow.profile.settings.v1.';

  final SharedPreferences _preferences;

  Future<ProfileIdentity?> loadIdentity(String userId) async {
    final raw = _preferences.getString('$_profilePrefix$userId');
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return ProfileIdentity.fromJson(Map<String, Object?>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveIdentity(ProfileIdentity identity) async {
    await _preferences.setString(
      '$_profilePrefix${identity.userId}',
      jsonEncode(identity.toJson()),
    );
  }

  Future<ProfileSettings> loadSettings(String userId) async {
    final raw = _preferences.getString('$_settingsPrefix$userId');
    if (raw == null || raw.trim().isEmpty) {
      return ProfileSettings.defaults;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return ProfileSettings.defaults;
      }
      return ProfileSettings.fromJson(Map<String, Object?>.from(decoded));
    } catch (_) {
      return ProfileSettings.defaults;
    }
  }

  Future<void> saveSettings(String userId, ProfileSettings settings) async {
    await _preferences.setString(
      '$_settingsPrefix$userId',
      jsonEncode(settings.toJson()),
    );
  }
}
