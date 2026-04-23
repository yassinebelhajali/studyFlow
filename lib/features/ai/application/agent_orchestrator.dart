import '../../../domain/models/ai/agent_action.dart';
import '../../../domain/models/ai/ai_conversation.dart';
import '../../../domain/services/ai/llm_service.dart';

class AgentRunUpdate {
  const AgentRunUpdate({this.textDelta, this.actions, this.isDone = false});

  final String? textDelta;
  final List<AgentAction>? actions;
  final bool isDone;
}

abstract interface class AgentOrchestrator {
  Stream<AgentRunUpdate> run({
    required AiConversation conversation,
    required String userMessage,
  });
}

class StudyAgentOrchestrator implements AgentOrchestrator {
  const StudyAgentOrchestrator({
    required LlmService llmService,
    bool preferStreaming = true,
  }) : _llmService = llmService,
       _preferStreaming = preferStreaming;

  final LlmService _llmService;
  final bool _preferStreaming;

  @override
  Stream<AgentRunUpdate> run({
    required AiConversation conversation,
    required String userMessage,
  }) async* {
    if (_preferStreaming) {
      await for (final update in _llmService.streamComplete(
        conversation: conversation,
        toolResults: const [],
      )) {
        if (update.actions != null) {
          yield AgentRunUpdate(actions: update.actions);
        }
        final delta = update.textDelta ?? '';
        if (delta.isNotEmpty) {
          yield AgentRunUpdate(textDelta: delta);
        }
        if (update.isDone) {
          yield const AgentRunUpdate(isDone: true);
          return;
        }
      }
    } else {
      final content = await _llmService.complete(
        conversation: conversation,
        toolResults: const [],
      );
      if (content.isNotEmpty) {
        yield AgentRunUpdate(textDelta: content);
      }
    }

    yield AgentRunUpdate(isDone: true);
  }
}
