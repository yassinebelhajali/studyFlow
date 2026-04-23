import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyflow/data/ai/ai_memory_store.dart';
import 'package:studyflow/domain/models/ai/ai_chat_message.dart';
import 'package:studyflow/domain/models/ai/ai_conversation.dart';

void main() {
  test('saves and restores a conversation by user id', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = AiMemoryStore(preferences);
    final now = DateTime(2026, 4, 22, 12);
    final conversation = AiConversation(
      id: 'conversation-1',
      userId: 'user-1',
      mode: AiConversationMode.agent,
      createdAt: now,
      updatedAt: now,
      messages: [
        AiChatMessage(
          id: 'message-1',
          conversationId: 'conversation-1',
          role: AiMessageRole.user,
          content: 'Plan my day',
          createdAt: now,
        ),
      ],
    );

    await store.saveConversation(conversation);

    final restored = await store.loadConversation('user-1');
    expect(restored?.id, 'conversation-1');
    expect(restored?.messages.single.content, 'Plan my day');
  });
}
