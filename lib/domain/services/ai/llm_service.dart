import '../../models/ai/ai_conversation.dart';
import '../../models/ai/agent_action.dart';
import '../../models/ai/tool_result.dart';

class LlmRunUpdate {
  const LlmRunUpdate({this.textDelta, this.actions, this.isDone = false});

  final String? textDelta;
  final List<AgentAction>? actions;
  final bool isDone;
}

abstract interface class LlmService {
  Future<String> complete({
    required AiConversation conversation,
    required List<ToolResult> toolResults,
  });

  Stream<LlmRunUpdate> streamComplete({
    required AiConversation conversation,
    required List<ToolResult> toolResults,
  });
}
