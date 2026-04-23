import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/ai/ai_conversation.dart';

class AiMemoryStore {
  AiMemoryStore(this._preferences);

  static const _prefix = 'studyflow.ai.conversation';

  final SharedPreferences _preferences;

  Future<AiConversation?> loadConversation(String userId) async {
    final raw = _preferences.getString(_key(userId));
    if (raw == null) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    return AiConversation.fromJson(decoded.cast<String, Object?>());
  }

  Future<void> saveConversation(AiConversation conversation) async {
    // Keep only the most recent messages locally. The backend SQLite store
    // carries authoritative long-term context, so there is no need to persist
    // the entire history in SharedPreferences (which has no size management).
    const maxStoredMessages = 60;
    final msgs = conversation.messages;
    final trimmed = msgs.length > maxStoredMessages
        ? conversation.copyWith(
            messages: msgs.sublist(msgs.length - maxStoredMessages),
          )
        : conversation;
    await _preferences.setString(
      _key(conversation.userId),
      jsonEncode(trimmed.toJson()),
    );
  }

  Future<void> clearConversation(String userId) async {
    await _preferences.remove(_key(userId));
  }

  String _key(String userId) => '$_prefix.$userId';
}
