import '../../domain/models/ai/agent_action.dart';
import 'ai_backend_client.dart';

class MockAiBackendClient implements AiBackendClient {
  const MockAiBackendClient();

  @override
  Future<AiChatResponse> sendChat(AiChatRequest request) async {
    return AiChatResponse(
      content: _buildResponse(request),
      requestId: request.requestId,
      mode: request.mode,
      conversationId: request.conversationId,
      isDone: true,
    );
  }

  @override
  Future<AiChatResponse> sendAgent(AiChatRequest request) async {
    return AiChatResponse(
      content: _buildResponse(request, isAgent: true),
      requestId: request.requestId,
      mode: request.mode,
      conversationId: request.conversationId,
      isDone: true,
    );
  }

  @override
  Stream<AiChatStreamEvent> streamChat(AiChatRequest request) async* {
    yield* _streamResponse(request);
  }

  @override
  Stream<AiChatStreamEvent> streamAgent(AiChatRequest request) async* {
    yield* _streamResponse(request, isAgent: true);
  }

  Stream<AiChatStreamEvent> _streamResponse(
    AiChatRequest request, {
    bool isAgent = false,
  }) async* {
    final lastMessage = request.messages.last.content.toLowerCase();
    final isAddTask = lastMessage.contains('add') &&
        (lastMessage.contains('task') || lastMessage.contains('english'));

    yield AiChatStreamEvent(
      type: AiBackendStreamEventType.meta,
      requestId: request.requestId,
      mode: request.mode,
    );

    if (isAgent && isAddTask) {
      // Emit a queued action first
      yield AiChatStreamEvent(
        type: AiBackendStreamEventType.action,
        requestId: request.requestId,
        mode: request.mode,
        actions: [
          AgentAction(
            id: 'mock-action-${DateTime.now().millisecondsSinceEpoch}',
            toolName: 'add_task',
            input: {'title': 'Learn English', 'subject': 'English Language'},
            status: AgentActionStatus.queued,
            createdAt: DateTime.now(),
          ),
        ],
      );
    }

    final response = _buildResponse(request, isAgent: isAgent);
    final parts = response.split(' ');
    for (final part in parts) {
      await Future<void>.delayed(const Duration(milliseconds: 18));
      yield AiChatStreamEvent(
        type: AiBackendStreamEventType.delta,
        textDelta: '$part ',
        requestId: request.requestId,
        mode: request.mode,
      );
    }
    yield AiChatStreamEvent(
      type: AiBackendStreamEventType.done,
      isDone: true,
      requestId: request.requestId,
      mode: request.mode,
    );
  }

  String _buildResponse(AiChatRequest request, {bool isAgent = false}) {
    String? lastUserMessage;
    for (final message in request.messages) {
      if (message.role.name == 'user') {
        lastUserMessage = message.content.trim();
      }
    }
    final toolContext = request.toolResults
        .where((item) => item.success)
        .map((item) => '- ${item.toolName}: ${item.summary}')
        .join('\n');

    final buffer = StringBuffer()
      ..writeln(isAgent ? 'Mock AI agent active.' : 'Mock AI backend active.')
      ..writeln()
      ..writeln(
        'I received your message: "${lastUserMessage?.isEmpty ?? true ? 'No prompt' : lastUserMessage}".',
      );

    if (toolContext.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Agent tool context used:')
        ..writeln(toolContext);
    }

    buffer
      ..writeln()
      ..write(
        'Connect a secure backend with STUDYFLOW_AI_BACKEND_URL to replace this deterministic local response with a real LLM.',
      );
    return buffer.toString();
  }
}
