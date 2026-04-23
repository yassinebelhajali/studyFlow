import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/notification_settings.dart';

class LocalNotificationSettingsStore extends ChangeNotifier {
  LocalNotificationSettingsStore(this._preferences);

  static const _storageKey = 'studyflow.notificationSettings.v1';

  final SharedPreferences _preferences;
  NotificationSettings _settings = NotificationSettings.defaults;
  bool _loaded = false;

  NotificationSettings get settings => _settings;

  Future<NotificationSettings> load() async {
    if (_loaded) {
      return _settings;
    }
    final encoded = _preferences.getString(_storageKey);
    if (encoded == null || encoded.trim().isEmpty) {
      _loaded = true;
      await save(NotificationSettings.defaults, notify: false);
      return _settings;
    }

    try {
      final decoded = jsonDecode(encoded);
      _settings = NotificationSettings.fromJson(
        Map<String, Object?>.from(decoded as Map),
      );
    } catch (_) {
      _settings = NotificationSettings.defaults;
      await save(_settings, notify: false);
    }
    _loaded = true;
    return _settings;
  }

  Future<void> save(NotificationSettings settings, {bool notify = true}) async {
    _settings = settings;
    await _preferences.setString(_storageKey, jsonEncode(settings.toJson()));
    if (notify) {
      notifyListeners();
    }
  }
}
