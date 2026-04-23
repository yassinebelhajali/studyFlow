import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/debug/app_logger.dart';
import '../../../domain/models/ai/agent_action.dart';
import '../../../domain/models/ai/ai_chat_message.dart';
import '../../../domain/models/ai/ai_conversation.dart';
import '../../../domain/models/ai/tool_result.dart';
import '../../../domain/repositories/chat_repository.dart';
import '../application/ai_tool.dart';

const _tag = 'ChatController';

class ChatController extends ChangeNotifier {
  ChatController({
    required String userId,
    required ChatRepository repository,
    required ToolRegistry tools,
  }) : _userId = userId,
       _repository = repository,
       _tools = tools;

  final String _userId;
  final ChatRepository _repository;
  final ToolRegistry _tools;

  AiConversation? _conversation;
  Future<void>? _restoreFuture;
  bool _isSending = false;
  String? _errorMessage;
  String? _lastFailedPrompt;
  int _idSeed = 0;
  int _restoreToken = 0;

  AiConversation? get conversation => _conversation;
  List<AiChatMessage> get messages =>
      _conversation?.messages ?? const <AiChatMessage>[];
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  bool get canRetry => !_isSending && _lastFailedPrompt != null;
  AiConversationMode get mode =>
      _conversation?.mode ?? AiConversationMode.agent;

  Future<void> restore() {
    return _restoreFuture ??= _restore(_restoreToken);
  }

  Future<void> setMode(AiConversationMode mode) async {
    await restore();
    final conversation = _ensureConversation().copyWith(
      mode: mode,
      updatedAt: DateTime.now(),
    );
    _conversation = conversation;
    notifyListeners();
    await _repository.saveConversation(conversation);
  }

  Future<void> resetConversation() async {
    _restoreToken += 1;
    _restoreFuture = Future<void>.value();
    _conversation = _newConversation();
    _errorMessage = null;
    _lastFailedPrompt = null;
    notifyListeners();
    await _repository.clearConversation(_userId);
  }

  Future<void> sendMessage(String rawText) async {
    await _sendMessage(rawText, appendUserMessage: true);
  }

  Future<void> retryLastFailedMessage() async {
    final prompt = _lastFailedPrompt;
    if (prompt == null || _isSending) {
      return;
    }
    await _sendMessage(prompt, appendUserMessage: false);
  }

  Future<void> _sendMessage(
    String rawText, {
    required bool appendUserMessage,
  }) async {
    final text = rawText.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    await restore();
    _isSending = true;
    _errorMessage = null;
    _lastFailedPrompt = null;

    final conversation = _ensureConversation();
    AppLogger.info(
      _tag,
      'sendMessage',
      data: {
        'conversationId': conversation.id,
        'mode': conversation.mode.name,
        'messageCount': conversation.messages.length,
        'textLength': text.length,
      },
    );
    final now = DateTime.now();
    final baseMessages = _withoutTrailingFailedAssistant(conversation.messages);
    final shouldAppendUser =
        appendUserMessage ||
        baseMessages.isEmpty ||
        baseMessages.last.role != AiMessageRole.user ||
        baseMessages.last.content.trim() != text;
    final userMessage = shouldAppendUser
        ? AiChatMessage(
            id: _newId('message'),
            conversationId: conversation.id,
            role: AiMessageRole.user,
            content: text,
            createdAt: now,
          )
        : null;
    final requestMessages = [...baseMessages, ?userMessage];
    final requestConversation = conversation.copyWith(
      title: conversation.messages.isEmpty
          ? _titleFrom(text)
          : conversation.title,
      updatedAt: now,
      messages: requestMessages,
    );
    final assistantMessage = AiChatMessage(
      id: _newId('message'),
      conversationId: conversation.id,
      role: AiMessageRole.assistant,
      content: '',
      createdAt: now,
      isStreaming: true,
      status: AiChatMessageStatus.streaming,
    );

    _conversation = requestConversation.copyWith(
      updatedAt: now,
      messages: [...requestMessages, assistantMessage],
    );
    notifyListeners();

    try {
      await _repository.saveConversation(requestConversation);
      await for (final update in _repository.streamAssistantResponse(
        conversation: requestConversation,
        userMessage: text,
      )) {
        if (update.actions != null) {
          _replaceAssistantMessage(
            assistantMessage.id,
            actions: update.actions,
          );
          // Automatically trigger execution for newly received actions
          unawaited(_executePendingActions(assistantMessage.id, text));
        }

        final delta = update.textDelta;
        if (delta != null && delta.isNotEmpty) {
          final current = _messageById(assistantMessage.id);
          _replaceAssistantMessage(
            assistantMessage.id,
            content: '${current?.content ?? ''}$delta',
          );
        }

        if (update.isDone) {
          _replaceAssistantMessage(
            assistantMessage.id,
            isStreaming: false,
            status: AiChatMessageStatus.sent,
          );
        }
        notifyListeners();
      }
    } catch (error, st) {
      final message = _friendlyError(error);
      AppLogger.error(
        _tag,
        'sendMessage failed',
        error: message,
        stackTrace: st,
      );
      _errorMessage = message;
      _lastFailedPrompt = text;
      _replaceAssistantMessage(
        assistantMessage.id,
        content: _failureContent(message),
        isStreaming: false,
        status: AiChatMessageStatus.failed,
        errorMessage: message,
      );
      notifyListeners();
    } finally {
      _isSending = false;
      final assistant = _messageById(assistantMessage.id);
      if (assistant != null && !assistant.hasError) {
        _replaceAssistantMessage(
          assistantMessage.id,
          isStreaming: false,
          status: AiChatMessageStatus.sent,
        );
      }
      notifyListeners();
      await _save();
    }
  }

  Future<void> _restore(int token) async {
    try {
      final restored = await _repository.loadConversation(_userId);
      if (token != _restoreToken) {
        return;
      }
      _conversation = restored;
      AppLogger.info(
        _tag,
        'restore complete',
        data: {
          'found': restored != null,
          'messageCount': restored?.messages.length ?? 0,
          'conversationId': restored?.id,
        },
      );
    } catch (error, st) {
      AppLogger.error(
        _tag,
        'restore failed — starting fresh',
        error: error,
        stackTrace: st,
      );
      if (token != _restoreToken) {
        return;
      }
      _conversation = null;
    }
    _conversation ??= _newConversation();
    _lastFailedPrompt = _retryPromptFor(_conversation!.messages);
    notifyListeners();
  }

  AiConversation _ensureConversation() {
    return _conversation ??= _newConversation();
  }

  AiConversation _newConversation() {
    final now = DateTime.now();
    return AiConversation(
      id: _newId('conversation'),
      userId: _userId,
      mode: AiConversationMode.agent,
      createdAt: now,
      updatedAt: now,
    );
  }

  AiChatMessage? _messageById(String id) {
    for (final message in messages) {
      if (message.id == id) {
        return message;
      }
    }
    return null;
  }

  void _replaceAssistantMessage(
    String id, {
    String? content,
    bool? isStreaming,
    AiChatMessageStatus? status,
    String? errorMessage,
    List<AgentAction>? actions,
  }) {
    final conversation = _ensureConversation();
    _conversation = conversation.copyWith(
      updatedAt: DateTime.now(),
      messages: conversation.messages
          .map((message) {
            if (message.id != id) {
              return message;
            }
            return message.copyWith(
              content: content,
              isStreaming: isStreaming,
              status: status,
              errorMessage: errorMessage,
              actions: actions,
            );
          })
          .toList(growable: false),
    );
  }

  Future<void> _executePendingActions(
    String messageId,
    String userMessage,
  ) async {
    final message = _messageById(messageId);
    if (message == null || message.actions.isEmpty) {
      return;
    }

    final pending = message.actions
        .where((a) => a.status == AgentActionStatus.queued)
        .toList();

    for (final action in pending) {
      await _executeAction(messageId, action, userMessage);
    }
  }

  Future<void> _executeAction(
    String messageId,
    AgentAction action,
    String userMessage,
  ) async {
    _updateActionStatus(messageId, action.id, AgentActionStatus.running);
    notifyListeners();

    final tool = _tools.getTool(action.toolName);
    if (tool == null) {
      _updateActionStatus(
        messageId,
        action.id,
        AgentActionStatus.failed,
        errorMessage: 'Tool "${action.toolName}" not found on frontend.',
      );
      notifyListeners();
      return;
    }

    try {
      final result = await tool.execute(
        AiToolContext(
          userId: _userId,
          userMessage: userMessage,
          now: DateTime.now(),
        ),
      );

      _updateActionStatus(
        messageId,
        action.id,
        result.success ? AgentActionStatus.succeeded : AgentActionStatus.failed,
        result: result,
      );
    } catch (e) {
      _updateActionStatus(
        messageId,
        action.id,
        AgentActionStatus.failed,
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
  }

  void _updateActionStatus(
    String messageId,
    String actionId,
    AgentActionStatus status, {
    ToolResult? result,
    String? errorMessage,
  }) {
    final message = _messageById(messageId);
    if (message == null) return;

    final updatedActions = message.actions.map((a) {
      if (a.id != actionId) return a;
      return a.copyWith(
        status: status,
        result: result,
        errorMessage: errorMessage,
        completedAt:
            status == AgentActionStatus.succeeded ||
                    status == AgentActionStatus.failed
                ? DateTime.now()
                : null,
      );
    }).toList();

    _replaceAssistantMessage(messageId, actions: updatedActions);
  }

  Future<void> _save() async {
    final conversation = _conversation;
    if (conversation != null) {
      await _repository.saveConversation(conversation);
    }
  }

  List<AiChatMessage> _withoutTrailingFailedAssistant(
    List<AiChatMessage> messages,
  ) {
    if (messages.isEmpty) {
      return messages;
    }
    final last = messages.last;
    if (last.role == AiMessageRole.assistant && last.hasError) {
      return messages.sublist(0, messages.length - 1);
    }
    return messages;
  }

  String? _retryPromptFor(List<AiChatMessage> messages) {
    if (messages.isEmpty) {
      return null;
    }
    final last = messages.last;
    if (last.role != AiMessageRole.assistant || !last.hasError) {
      return null;
    }
    for (final message in messages.reversed.skip(1)) {
      if (message.role == AiMessageRole.user &&
          message.content.trim().isNotEmpty) {
        return message.content;
      }
    }
    return null;
  }

  String _friendlyError(Object error) {
    final message = error.toString().trim();
    if (message.isEmpty) {
      return 'AI backend request failed.';
    }
    final normalized = message
        .replaceFirst('Exception: ', '')
        .replaceFirst('AiBackendException: ', '')
        .replaceFirst('ChatRepositoryException: ', '');
    final lower = normalized.toLowerCase();
    if (normalized.contains('UNAVAILABLE') ||
        lower.contains('high demand') ||
        lower.contains('failed with 503') ||
        lower.contains('status 503') ||
        lower.contains('status 429')) {
      return 'The AI model is temporarily busy. Please retry in a moment.';
    }
    if (lower.contains('timed out')) {
      return 'The AI request timed out. Please retry in a moment.';
    }
    return normalized;
  }

  String _failureContent(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('busy') ||
        lower.contains('temporarily unavailable') ||
        lower.contains('timed out')) {
      return '$message You can retry, or ask for a shorter planning request.';
    }
    if (lower.contains('configured') || lower.contains('connection')) {
      return 'I could not reach the AI backend. Check the backend connection and try again.';
    }
    return 'I could not complete that request. Please try again.';
  }

  String _titleFrom(String text) {
    if (text.length <= 40) {
      return text;
    }
    return '${text.substring(0, 37)}...';
  }

  String _newId(String prefix) {
    _idSeed += 1;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idSeed';
  }
}
