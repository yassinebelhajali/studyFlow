import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/models/ai/agent_action.dart';
import '../../../domain/models/ai/ai_chat_message.dart';
import '../../../domain/models/ai/ai_conversation.dart';
import 'chat_controller.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.controller,
    required this.isMockBackend,
  });

  final ChatController controller;
  final bool isMockBackend;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.restore());
    widget.controller.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scrollToBottom);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submit() {
    _sendPrompt(_textController.text);
  }

  void _sendPrompt(String rawText) {
    if (widget.controller.isSending) {
      return;
    }
    final text = rawText.trim();
    if (text.trim().isEmpty) {
      return;
    }
    _textController.clear();
    unawaited(widget.controller.sendMessage(text));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final mode = widget.controller.mode;
        return Scaffold(
          appBar: AppBar(
            title: const Text('AI Study Assistant'),
            actions: [
              PopupMenuButton<AiConversationMode>(
                initialValue: mode,
                tooltip: 'Assistant mode',
                onSelected: widget.controller.setMode,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: AiConversationMode.chat,
                    child: Text('Chat'),
                  ),
                  PopupMenuItem(
                    value: AiConversationMode.agent,
                    child: Text('Agent'),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Chip(
                    label: Text(
                      mode == AiConversationMode.agent ? 'Agent' : 'Chat',
                    ),
                    avatar: Icon(
                      mode == AiConversationMode.agent
                          ? Icons.hub_rounded
                          : Icons.chat_bubble_rounded,
                      size: 18,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'New chat',
                onPressed: widget.controller.resetConversation,
                icon: const Icon(Icons.add_comment_rounded),
              ),
            ],
          ),
          body: Column(
            children: [
              if (widget.isMockBackend) const _MockBackendBanner(),
              _ModeHint(mode: mode),
              if (widget.controller.errorMessage != null)
                _ErrorBanner(
                  message: widget.controller.errorMessage!,
                  canRetry: widget.controller.canRetry,
                  onRetry: widget.controller.retryLastFailedMessage,
                ),
              Expanded(
                child: widget.controller.messages.isEmpty
                    ? _EmptyChat(onPromptSelected: _sendPrompt)
                    : ListView.builder(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: widget.controller.messages.length,
                        itemBuilder: (context, index) {
                          return _MessageBubble(
                            message: widget.controller.messages[index],
                            onRetry: widget.controller.retryLastFailedMessage,
                          );
                        },
                      ),
              ),
              _Composer(
                controller: _textController,
                isSending: widget.controller.isSending,
                onSubmit: _submit,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onRetry});

  final AiChatMessage message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AiMessageRole.user;
    final hasError = message.hasError;
    final bubbleColor = isUser ? const Color(0xFF2563EB) : Colors.white;
    final textColor = isUser ? Colors.white : const Color(0xFF172033);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          border: isUser
              ? null
              : Border.all(
                  color: hasError
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFFE2E8F0),
                ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.actions.isNotEmpty) ...[
              _ActionList(actions: message.actions),
              const SizedBox(height: 10),
            ],
            if (message.content.isEmpty && message.isStreaming)
              const _TypingIndicator()
            else
              Text(
                message.content,
                style: TextStyle(
                  color: textColor,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (message.errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                message.errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (hasError && !isUser) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB91C1C),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                ),
              ),
            ],
            if (message.isStreaming) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionList extends StatelessWidget {
  const _ActionList({required this.actions});

  final List<AgentAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: actions
          .map((action) => _ActionStatusTile(action: action))
          .toList(growable: false),
    );
  }
}

class _ActionStatusTile extends StatelessWidget {
  const _ActionStatusTile({required this.action});

  final AgentAction action;

  @override
  Widget build(BuildContext context) {
    final statusColor = _colorFor(action.status);
    final summary = action.result?.summary.trim();
    final error = action.errorMessage?.trim();
    final detail = error?.isNotEmpty == true ? error : summary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(action.status), size: 18, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_labelForTool(action.toolName)} - ${_labelForStatus(action.status)}',
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(AgentActionStatus status) {
    return switch (status) {
      AgentActionStatus.queued => Icons.pending_rounded,
      AgentActionStatus.running => Icons.sync_rounded,
      AgentActionStatus.succeeded => Icons.check_circle_rounded,
      AgentActionStatus.failed => Icons.error_rounded,
    };
  }

  Color _colorFor(AgentActionStatus status) {
    return switch (status) {
      AgentActionStatus.queued => const Color(0xFF64748B),
      AgentActionStatus.running => const Color(0xFF2563EB),
      AgentActionStatus.succeeded => const Color(0xFF059669),
      AgentActionStatus.failed => const Color(0xFFDC2626),
    };
  }

  String _labelForStatus(AgentActionStatus status) {
    return switch (status) {
      AgentActionStatus.queued => 'queued',
      AgentActionStatus.running => 'checking',
      AgentActionStatus.succeeded => 'done',
      AgentActionStatus.failed => 'failed',
    };
  }

  String _labelForTool(String toolName) {
    return switch (toolName) {
      'get_today_schedule' => 'Today schedule',
      'get_weekly_schedule' => 'Weekly schedule',
      'build_study_plan' => 'Study plan',
      _ => toolName.replaceAll('_', ' '),
    };
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (!isSending) {
                    onSubmit();
                  }
                },
                decoration: const InputDecoration(
                  hintText: 'Message the assistant',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: isSending ? null : onSubmit,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockBackendBanner extends StatelessWidget {
  const _MockBackendBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF7ED),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Text(
        'Mock AI backend enabled. Configure STUDYFLOW_AI_BACKEND_URL for real LLM responses.',
        style: TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ModeHint extends StatelessWidget {
  const _ModeHint({required this.mode});

  final AiConversationMode mode;

  @override
  Widget build(BuildContext context) {
    final isAgent = mode == AiConversationMode.agent;
    return Container(
      width: double.infinity,
      color: isAgent ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            isAgent ? Icons.hub_rounded : Icons.chat_bubble_rounded,
            size: 18,
            color: isAgent ? const Color(0xFF2563EB) : const Color(0xFF475569),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isAgent
                  ? 'Agent mode can use StudyFlow actions like schedules and study planning.'
                  : 'Chat mode answers directly without using StudyFlow actions.',
              style: TextStyle(
                color: isAgent
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF475569),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.canRetry,
    required this.onRetry,
  });

  final String message;
  final bool canRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFEF2F2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (canRetry) ...[
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Text(
          'Thinking...',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onPromptSelected});

  final ValueChanged<String> onPromptSelected;

  static const _prompts = [
    'Build a 90-minute study plan for today',
    'Check my schedule and plan around it',
    'Quiz me on the topic I am revising',
    'Break this homework into steps',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF2563EB),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'What do you want to improve right now?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF172033),
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ask for a plan, schedule check, explanation, quiz, or homework breakdown.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: _prompts
                    .map(
                      (prompt) => ActionChip(
                        avatar: const Icon(Icons.bolt_rounded, size: 16),
                        tooltip: prompt,
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(prompt, overflow: TextOverflow.ellipsis),
                        ),
                        onPressed: () => onPromptSelected(prompt),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
