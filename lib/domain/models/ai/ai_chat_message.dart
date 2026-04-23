import 'agent_action.dart';

enum AiMessageRole { system, user, assistant, tool }

enum AiChatMessageStatus { sent, streaming, failed }

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isStreaming = false,
    AiChatMessageStatus? status,
    this.errorMessage,
    this.actions = const <AgentAction>[],
  }) : status =
           status ??
           (isStreaming
               ? AiChatMessageStatus.streaming
               : AiChatMessageStatus.sent);

  final String id;
  final String conversationId;
  final AiMessageRole role;
  final String content;
  final DateTime createdAt;
  final bool isStreaming;
  final AiChatMessageStatus status;
  final String? errorMessage;
  final List<AgentAction> actions;

  bool get hasError => status == AiChatMessageStatus.failed;

  AiChatMessage copyWith({
    String? content,
    bool? isStreaming,
    AiChatMessageStatus? status,
    String? errorMessage,
    List<AgentAction>? actions,
  }) {
    return AiChatMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      isStreaming: isStreaming ?? this.isStreaming,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      actions: actions ?? this.actions,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'role': role.name,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'errorMessage': errorMessage,
      'actions': actions.map((item) => item.toJson()).toList(growable: false),
    };
  }

  factory AiChatMessage.fromJson(Map<String, Object?> json) {
    final restoredStatus = AiChatMessageStatus.values.firstWhere(
      (item) => item.name == json['status'],
      orElse: () => AiChatMessageStatus.sent,
    );
    return AiChatMessage(
      id: json['id'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      role: AiMessageRole.values.firstWhere(
        (item) => item.name == json['role'],
        orElse: () => AiMessageRole.assistant,
      ),
      content: json['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isStreaming: false,
      status: restoredStatus == AiChatMessageStatus.streaming
          ? AiChatMessageStatus.failed
          : restoredStatus,
      errorMessage: json['errorMessage'] as String?,
      actions:
          (json['actions'] as List?)
              ?.whereType<Map>()
              .map((item) => AgentAction.fromJson(item.cast<String, Object?>()))
              .toList(growable: false) ??
          const <AgentAction>[],
    );
  }
}
