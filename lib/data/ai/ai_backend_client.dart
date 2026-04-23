import '../../domain/models/ai/agent_action.dart';
import '../../domain/models/ai/ai_chat_message.dart';
import '../../domain/models/ai/ai_conversation.dart';
import '../../domain/models/ai/tool_result.dart';

class AiChatRequest {
  const AiChatRequest({
    this.requestId = '',
    required this.conversationId,
    required this.userId,
    required this.mode,
    required this.messages,
    required this.toolResults,
  });

  final String requestId;
  final String conversationId;
  final String userId;
  final AiConversationMode mode;
  final List<AiChatMessage> messages;
  final List<ToolResult> toolResults;

  Map<String, Object?> toJson() {
    return {
      if (requestId.isNotEmpty) 'requestId': requestId,
      'conversationId': conversationId,
      'userId': userId,
      'mode': mode.name,
      'messages': messages.map((item) => item.toJson()).toList(growable: false),
      'toolResults': toolResults
          .map((item) => item.toJson())
          .toList(growable: false),
    };
  }
}

class AiChatResponse {
  const AiChatResponse({
    required this.content,
    this.ok = true,
    this.requestId,
    this.mode,
    this.conversationId,
    this.errorMessage,
    this.actions = const <AgentAction>[],
    this.toolResults = const <ToolResult>[],
    this.isDone = true,
  });

  final bool ok;
  final String? requestId;
  final AiConversationMode? mode;
  final String? conversationId;
  final String content;
  final String? errorMessage;
  final List<AgentAction> actions;
  final List<ToolResult> toolResults;
  final bool isDone;

  factory AiChatResponse.fromJson(Map<String, Object?> json) {
    final payload = _unwrapPayload(json);
    return AiChatResponse(
      ok: payload['ok'] as bool? ?? true,
      requestId: payload['requestId'] as String?,
      mode: parseAiConversationMode(payload['mode']),
      conversationId: payload['conversationId'] as String?,
      content: payload['content'] as String? ?? '',
      errorMessage: _readErrorMessage(payload),
      actions:
          (payload['actions'] as List?)
              ?.whereType<Map>()
              .map((item) => AgentAction.fromJson(item.cast<String, Object?>()))
              .toList(growable: false) ??
          const <AgentAction>[],
      toolResults:
          (payload['toolResults'] as List?)
              ?.whereType<Map>()
              .map((item) => ToolResult.fromJson(item.cast<String, Object?>()))
              .toList(growable: false) ??
          const <ToolResult>[],
      isDone: payload['done'] == true || payload['isDone'] == true,
    );
  }
}

enum AiBackendStreamEventType { meta, delta, action, error, done }

class AiChatStreamEvent {
  const AiChatStreamEvent({
    this.type = AiBackendStreamEventType.delta,
    this.textDelta,
    this.actions,
    this.errorMessage,
    this.isDone = false,
    this.requestId,
    this.mode,
  });

  final AiBackendStreamEventType type;
  final String? textDelta;
  final List<AgentAction>? actions;
  final String? errorMessage;
  final bool isDone;
  final String? requestId;
  final AiConversationMode? mode;
}

abstract interface class AiBackendClient {
  Future<AiChatResponse> sendChat(AiChatRequest request);

  Future<AiChatResponse> sendAgent(AiChatRequest request);

  Stream<AiChatStreamEvent> streamChat(AiChatRequest request);

  Stream<AiChatStreamEvent> streamAgent(AiChatRequest request);
}

class AiBackendException implements Exception {
  const AiBackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, Object?> _unwrapPayload(Map<String, Object?> json) {
  final data = json['data'];
  if (json['ok'] == true && data is Map) {
    return data.cast<String, Object?>();
  }
  return json;
}

AiConversationMode? parseAiConversationMode(Object? value) {
  if (value is! String) {
    return null;
  }
  return AiConversationMode.values.firstWhere(
    (item) => item.name == value,
    orElse: () => AiConversationMode.agent,
  );
}

String? _readErrorMessage(Map<String, Object?> payload) {
  final error = payload['error'];
  if (error is Map) {
    final message = error['message'];
    final detail = error['detail'];
    if (message is String && detail is String && detail.isNotEmpty) {
      return '$message: $detail';
    }
    if (message is String) {
      return message;
    }
  }
  if (payload['errorMessage'] is String) {
    return payload['errorMessage'] as String;
  }
  return null;
}
