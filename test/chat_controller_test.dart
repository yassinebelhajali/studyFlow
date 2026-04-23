import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/domain/models/ai/ai_chat_message.dart';
import 'package:studyflow/domain/models/ai/ai_conversation.dart';
import 'package:studyflow/domain/repositories/chat_repository.dart';
import 'package:studyflow/features/ai/application/ai_tool.dart';
import 'package:studyflow/features/ai/presentation/chat_controller.dart';

class _FakeChatRepository implements ChatRepository {
  AiConversation? savedConversation;
  AiConversation? requestConversation;
  bool fail = false;
  String failureMessage = 'backend unavailable';

  @override
  Future<AiConversation?> loadConversation(String userId) async {
    return savedConversation;
  }

  @override
  Future<void> saveConversation(AiConversation conversation) async {
    savedConversation = conversation;
  }

  @override
  Future<void> clearConversation(String userId) async {
    savedConversation = null;
  }

  @override
  Stream<ChatResponseChunk> streamAssistantResponse({
    required AiConversation conversation,
    required String userMessage,
  }) async* {
    requestConversation = conversation;
    if (fail) {
      throw ChatRepositoryException(failureMessage);
    }
    yield const ChatResponseChunk(textDelta: 'Hello ');
    yield const ChatResponseChunk(textDelta: 'student.');
    yield const ChatResponseChunk(isDone: true);
  }
}

void main() {
  test('sendMessage appends user and streamed assistant messages', () async {
    final repository = _FakeChatRepository();
    final controller = ChatController(
      userId: 'user-1',
      repository: repository,
      tools: ToolRegistry([]),
    );

    await controller.sendMessage('Hi');

    expect(controller.messages.length, 2);
    expect(controller.messages.first.content, 'Hi');
    expect(controller.messages.last.content, 'Hello student.');
    expect(controller.messages.last.isStreaming, isFalse);
    expect(controller.isSending, isFalse);
    expect(repository.requestConversation?.messages.length, 1);
    expect(
      repository.requestConversation?.messages.single.role,
      AiMessageRole.user,
    );
  });

  test(
    'retry resends the last failed prompt without duplicating user message',
    () async {
      final repository = _FakeChatRepository()..fail = true;
      final controller = ChatController(
        userId: 'user-1',
        repository: repository,
        tools: ToolRegistry([]),
      );

      await controller.sendMessage('Plan my day');

      expect(controller.canRetry, isTrue);
      expect(controller.messages.length, 2);
      expect(controller.messages.last.status, AiChatMessageStatus.failed);

      repository.fail = false;
      await controller.retryLastFailedMessage();

      expect(controller.messages.length, 2);
      expect(controller.messages.first.content, 'Plan my day');
      expect(controller.messages.last.content, 'Hello student.');
      expect(controller.messages.last.status, AiChatMessageStatus.sent);
    },
  );

  test(
    'sendMessage replaces raw provider overload errors with friendly copy',
    () async {
      final repository = _FakeChatRepository()
        ..fail = true
        ..failureMessage =
            'AI backend stream failed: LLM provider failed with 503: {"error":{"message":"This model is currently experiencing high demand","status":"UNAVAILABLE"}}';
      final controller = ChatController(
        userId: 'user-1',
        repository: repository,
        tools: ToolRegistry([]),
      );

      await controller.sendMessage('Plan my day');

      expect(
        controller.errorMessage,
        'The AI model is temporarily busy. Please retry in a moment.',
      );
      expect(
        controller.messages.last.errorMessage,
        'The AI model is temporarily busy. Please retry in a moment.',
      );
    },
  );
}
