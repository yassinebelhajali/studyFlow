import '../../domain/models/ai/ai_conversation.dart';
import '../../domain/models/ai/tool_result.dart';
import '../../domain/services/ai/llm_service.dart';
import 'ai_backend_client.dart';

class BackendLlmService implements LlmService {
  const BackendLlmService(this._client);

  final AiBackendClient _client;

  @override
  Future<String> complete({
    required AiConversation conversation,
    required List<ToolResult> toolResults,
  }) async {
    final response = await _client.sendChat(
      AiChatRequest(
        conversationId: conversation.id,
        userId: conversation.userId,
        mode: conversation.mode,
        messages: conversation.messages,
        toolResults: toolResults,
      ),
    );
    return response.content;
  }

  @override
  Stream<LlmRunUpdate> streamComplete({
    required AiConversation conversation,
    required List<ToolResult> toolResults,
  }) async* {
    await for (final event in _client.streamChat(
      AiChatRequest(
        conversationId: conversation.id,
        userId: conversation.userId,
        mode: conversation.mode,
        messages: conversation.messages,
        toolResults: toolResults,
      ),
    )) {
      yield LlmRunUpdate(
        textDelta: event.textDelta,
        actions: event.actions,
        isDone: event.isDone,
      );
    }
  }
}
