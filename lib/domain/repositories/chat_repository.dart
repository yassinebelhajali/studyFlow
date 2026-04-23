import '../models/ai/agent_action.dart';
import '../models/ai/ai_conversation.dart';

class ChatResponseChunk {
  const ChatResponseChunk({this.textDelta, this.actions, this.isDone = false});

  final String? textDelta;
  final List<AgentAction>? actions;
  final bool isDone;
}

abstract interface class ChatRepository {
  Future<AiConversation?> loadConversation(String userId);

  Future<void> saveConversation(AiConversation conversation);

  Future<void> clearConversation(String userId);

  Stream<ChatResponseChunk> streamAssistantResponse({
    required AiConversation conversation,
    required String userMessage,
  });
}

class ChatRepositoryException implements Exception {
  const ChatRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
