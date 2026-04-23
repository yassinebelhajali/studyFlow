import '../../domain/models/ai/ai_conversation.dart';
import '../../domain/models/ai/tool_result.dart';
import '../../domain/repositories/chat_repository.dart';
import 'ai_backend_client.dart';
import 'ai_memory_store.dart';

class StudyChatRepository implements ChatRepository {
  const StudyChatRepository({
    required AiMemoryStore memoryStore,
    required AiBackendClient client,
    bool preferStreaming = true,
  }) : _memoryStore = memoryStore,
       _client = client,
       _preferStreaming = preferStreaming;

  final AiMemoryStore _memoryStore;
  final AiBackendClient _client;
  final bool _preferStreaming;

  @override
  Future<AiConversation?> loadConversation(String userId) {
    return _memoryStore.loadConversation(userId);
  }

  @override
  Future<void> saveConversation(AiConversation conversation) {
    return _memoryStore.saveConversation(conversation);
  }

  @override
  Future<void> clearConversation(String userId) {
    return _memoryStore.clearConversation(userId);
  }

  @override
  Stream<ChatResponseChunk> streamAssistantResponse({
    required AiConversation conversation,
    required String userMessage,
  }) async* {
    final request = _requestFor(conversation, userMessage);
    if (!_preferStreaming) {
      final response = await _send(request, conversation.mode);
      yield ChatResponseChunk(
        textDelta: response.content,
        actions: response.actions,
        isDone: true,
      );
      return;
    }

    final stream = conversation.mode == AiConversationMode.agent
        ? _client.streamAgent(request)
        : _client.streamChat(request);

    await for (final event in stream) {
      if (event.type == AiBackendStreamEventType.error) {
        throw AiBackendException(
          event.errorMessage ?? 'AI backend stream failed',
        );
      }

      yield ChatResponseChunk(
        textDelta: event.textDelta,
        actions: event.actions,
        isDone: event.isDone || event.type == AiBackendStreamEventType.done,
      );
    }
  }

  AiChatRequest _requestFor(AiConversation conversation, String userMessage) {
    // Send only the most recent window to the backend. The backend's SQLite
    // memory fills in older context when needed (e.g. new device / cleared
    // history), so we do not need to send the entire history on every request.
    const maxMessages = 20;
    final allMessages = conversation.messages;
    final messages = allMessages.length > maxMessages
        ? allMessages.sublist(allMessages.length - maxMessages)
        : allMessages;
    final requestId = _newRequestId(conversation.id);
    return AiChatRequest(
      requestId: requestId,
      conversationId: conversation.id,
      userId: conversation.userId,
      mode: conversation.mode,
      messages: messages,
      toolResults: const <ToolResult>[],
    );
  }

  Future<AiChatResponse> _send(AiChatRequest request, AiConversationMode mode) {
    return mode == AiConversationMode.agent
        ? _client.sendAgent(request)
        : _client.sendChat(request);
  }

  String _newRequestId(String conversationId) {
    return 'request_${DateTime.now().microsecondsSinceEpoch}_$conversationId';
  }
}
