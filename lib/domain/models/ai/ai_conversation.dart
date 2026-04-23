import 'ai_chat_message.dart';

enum AiConversationMode { chat, agent }

class AiConversation {
  const AiConversation({
    required this.id,
    required this.userId,
    required this.mode,
    required this.createdAt,
    required this.updatedAt,
    this.title = 'Study chat',
    this.messages = const <AiChatMessage>[],
  });

  final String id;
  final String userId;
  final String title;
  final AiConversationMode mode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AiChatMessage> messages;

  AiConversation copyWith({
    String? title,
    AiConversationMode? mode,
    DateTime? updatedAt,
    List<AiChatMessage>? messages,
  }) {
    return AiConversation(
      id: id,
      userId: userId,
      title: title ?? this.title,
      mode: mode ?? this.mode,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'mode': mode.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'messages': messages.map((item) => item.toJson()).toList(growable: false),
    };
  }

  factory AiConversation.fromJson(Map<String, Object?> json) {
    return AiConversation(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? 'Study chat',
      mode: AiConversationMode.values.firstWhere(
        (item) => item.name == json['mode'],
        orElse: () => AiConversationMode.agent,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      messages:
          (json['messages'] as List?)
              ?.whereType<Map>()
              .map(
                (item) => AiChatMessage.fromJson(item.cast<String, Object?>()),
              )
              .toList(growable: false) ??
          const <AiChatMessage>[],
    );
  }
}
