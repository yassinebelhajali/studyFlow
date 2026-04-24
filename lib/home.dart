import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'domain/models/schedule_session.dart';
import 'domain/repositories/schedule_repository.dart';
import 'domain/repositories/task_repository.dart';

// --- CONFIGURATION DES SUGGESTIONS ---
const List<String> suggestedPrompts = [
  'Plan my day',
  'Help with homework',
  'Organize my tasks',
  'What should I study today?',
];

class HomePage extends StatefulWidget {
  final String userName; // Requis par ton main
  final ValueChanged<String> onNavigate; // Requis par ton main
  final VoidCallback onOpenChat;
  final ValueChanged<String> onStartChatPrompt;
  final VoidCallback onNotificationTap;

  const HomePage({
    super.key,
    required this.userName,
    required this.onNavigate,
    required this.onOpenChat,
    required this.onStartChatPrompt,
    required this.onNotificationTap,
    required this.scheduleRepository,
    required this.taskRepository,
  });

  final ScheduleRepository scheduleRepository;
  final TaskRepository taskRepository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  String _lastPrompt = 'No message sent yet';
  ScheduleSession? _nextSession;
  int _pendingTasksCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final now = DateTime.now();
      final sessions = await widget.scheduleRepository.getWeeklySchedule();
      final todaySessions = sessions
          .where((s) => s.dayIndex == now.weekday - 1)
          .toList();
      todaySessions.sort((a, b) => a.start.compareTo(b.start));

      final next = todaySessions.firstWhere(
        (s) => s.startsAfter(now),
        orElse: () => todaySessions.firstWhere(
          (s) => s.isCurrentAt(now),
          orElse: () => sessions.firstWhere(
            (s) => s.dayIndex > (now.weekday - 1),
            orElse: () => sessions.isNotEmpty
                ? sessions.first
                : todaySessions.first, // Fallback
          ),
        ),
      );

      final tasks = await widget.taskRepository.getTasks();
      final pendingCount = tasks.where((t) => !t.completed).length;

      if (mounted) {
        setState(() {
          _nextSession = next;
          _pendingTasksCount = pendingCount;
        });
      }
    } catch (_) {}
  }

  void _submitPrompt() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _lastPrompt = text;
    });
    _controller.clear();
    widget.onStartChatPrompt(text);
  }

  void _fillPrompt(String value) {
    setState(() {
      _controller.text = value;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 390;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 14 : 20,
                18,
                isCompact ? 14 : 20,
                110, // Padding pour le BottomNav
              ),
              children: [
                // 1. --- HEADER AVEC AVATAR ---
                Container(
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 12 : 24,
                    isCompact ? 18 : 40,
                    isCompact ? 12 : 24,
                    20,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.05),
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome Back!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isCompact ? 24 : 28,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.onSurface,
                                letterSpacing: -0.5,
                                shadows: [
                                  Shadow(
                                    color: Theme.of(
                                      context,
                                    ).shadowColor.withValues(alpha: 0.05),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildNotificationButton(),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Divider(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  height: 1,
                ),
                const SizedBox(height: 20),

                // 2. --- AI ASSISTANT SECTION (DESIGN ORIGINAL COMPLEXE) ---
                _buildFullAICard(isCompact),

                const SizedBox(height: 20),

                // 3. --- QUICK INFO CARDS ---
                _buildQuickInfoCards(),

                const SizedBox(height: 18),

                // 4. --- TODAY'S SCHEDULE ---
                _buildScheduleSection(),

                const SizedBox(height: 15),

                // 5. --- LAST PROMPT HISTORY ---
                _buildLastPromptCard(),

                const SizedBox(height: 20),

                // 6. --- PAGER DOTS ---
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PagerDot(active: false),
                    SizedBox(width: 8),
                    _PagerDot(active: false),
                    SizedBox(width: 8),
                    _PagerDot(active: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickInfoCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth < 500 ? 1 : 3;
        final spacing = maxWidth < 500 ? 10.0 : 12.0;
        final cardWidth = (maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _QuickInfoCard(
                icon: Icons.calendar_month_rounded,
                iconColor: Theme.of(context).colorScheme.primary,
                title: 'Next Class',
                line1: _nextSession?.displayTitle ?? 'No classes',
                line2: _nextSession != null
                    ? '${_formatDuration(_nextSession!.start)} - ${_nextSession!.room}'
                    : 'Enjoy your day!',
                onTap: () => widget.onNavigate('emploi'),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _QuickInfoCard(
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Tasks',
                line1: '$_pendingTasksCount tasks',
                line2: 'remaining today',
                largeStat: true,
                onTap: () => widget.onNavigate('tasks'),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: const _QuickInfoCard(
                icon: Icons.tips_and_updates_rounded,
                iconColor: Color(0xFFF59E0B),
                title: 'Study Tip',
                line1: 'Active Recall',
                line2: 'Try flashcards',
              ),
            ),
          ],
        );
      },
    );
  }

  // --- WIDGETS DE CONSTRUCTION DÃ‰TAILLÃ‰S ---

  Widget _buildNotificationButton() {
    return GestureDetector(
      onTap: widget.onNotificationTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.notifications_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 26,
            ),
          ),
          Positioned(
            top: 10,
            right: 11,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullAICard(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
            Theme.of(context).colorScheme.tertiaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(isCompact ? 24 : 32),
        border: Border.all(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          // Illustration avec Stack (Design Original)
          _buildAIIllustration(isCompact),
          const SizedBox(height: 18),
          Text(
            'AI Study Assistant',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: isCompact ? 20 : 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me to summarize, plan or help with exercises',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: isCompact ? 13 : 14,
            ),
          ),
          const SizedBox(height: 20),
          // Input
          _buildAIInput(isCompact),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: widget.onOpenChat,
            icon: const Icon(Icons.chat_bubble_rounded, size: 18),
            label: const Text('Open full chat'),
          ),
          const SizedBox(height: 15),
          // Chips
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 10,
            children: suggestedPrompts
                .map((p) => _buildSuggestionChip(p))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAIIllustration(bool isCompact) {
    final robotSize = isCompact ? 132.0 : 160.0;

    return SizedBox(
      width: double.infinity,
      height: isCompact ? 138 : 170,
      child: Center(child: _AssistantRobotIcon(size: robotSize)),
    );
  }

  Widget _buildAIInput(bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Type your question...',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              onSubmitted: (_) => _submitPrompt(),
            ),
          ),
          GestureDetector(
            onTap: _submitPrompt,
            child: Container(
              padding: EdgeInsets.all(isCompact ? 9 : 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.send_rounded,
                color: Theme.of(context).colorScheme.surface,
                size: isCompact ? 18 : 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return InkWell(
      onTap: () => _fillPrompt(text),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    if (_nextSession == null) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HeaderIcon(
                icon: Icons.event_note_rounded,
                color: Color(0xFFF97316),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Next Session',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _ScheduleRow(
            time: _formatDuration(_nextSession!.start),
            title: _nextSession!.displayTitle,
            subtitle: '${_nextSession!.room} - ${_nextSession!.teacher}',
            iconColor: Color(_nextSession!.colorValue),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  Widget _buildLastPromptCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last interaction',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _lastPrompt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS DE SUPPORT (PIXEL PERFECT) ---

class _AssistantRobotIcon extends StatefulWidget {
  const _AssistantRobotIcon({required this.size});

  final double size;

  @override
  State<_AssistantRobotIcon> createState() => _AssistantRobotIconState();
}

class _AssistantRobotIconState extends State<_AssistantRobotIcon>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    // Changed video to ChatbotV as requested
    _controller = VideoPlayerController.asset('images/ChatbotV.mp4')
      ..setLooping(true)
      ..setVolume(0.0) // muted
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.play(); // autoplay
        }
      });

    // Subtle floating animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Floating Animated Robot (Background removed)
        AnimatedBuilder(
          animation: _floatAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _floatAnimation.value),
              child: child,
            );
          },
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: _controller.value.isInitialized
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surface,
                      child: Icon(
                        Icons.smart_toy_rounded,
                        size: widget.size * 0.5,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.8),
                      ),
                    ),
            ),
          ),
        ),

        // Floating Stars for premium AI feel
        Positioned(
          top: -5,
          right: -6,
          child: AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -_floatAnimation.value * 0.5),
                child: child,
              );
            },
            child: Icon(
              Icons.auto_awesome,
              color: Theme.of(context).colorScheme.surface,
              size: widget.size * 0.15,
            ),
          ),
        ),
        Positioned(
          bottom: widget.size * 0.1,
          left: -4,
          child: AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatAnimation.value * 0.3),
                child: child,
              );
            },
            child: Icon(
              Icons.auto_awesome,
              color: Theme.of(context).colorScheme.surface,
              size: widget.size * 0.1,
            ),
          ),
        ),
      ],
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding, this.gradient});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: gradient == null ? Theme.of(context).colorScheme.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
        ),
      ),
      child: child,
    );
  }
}

class _QuickInfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String line1;
  final String line2;
  final VoidCallback? onTap;
  final bool largeStat;
  const _QuickInfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.line1,
    required this.line2,
    this.onTap,
    this.largeStat = false,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 104),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                line1,
                maxLines: largeStat ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: largeStat ? 15 : 13,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                line2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final String time;
  final String title;
  final String subtitle;
  final Color iconColor;
  const _ScheduleRow({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.iconColor,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 70,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              time,
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _HeaderIcon({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _PagerDot extends StatelessWidget {
  final bool active;
  const _PagerDot({required this.active});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 22 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
