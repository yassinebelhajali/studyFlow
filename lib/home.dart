import 'package:flutter/material.dart';

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

  const HomePage({
    super.key,
    required this.userName,
    required this.onNavigate,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  String _lastPrompt = 'No message sent yet';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitPrompt() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _lastPrompt = text;
    });
    _controller.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2563EB),
        behavior: SnackBarBehavior.floating,
        content: Text('Prompt sent to AI: $text'),
      ),
    );
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
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 390;

    return Container(
      color: const Color(0xFFF5F7FB),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 16 : 20,
            18,
            isCompact ? 16 : 20,
            110, // Padding pour le BottomNav
          ),
          children: [
            // 1. --- HEADER AVEC AVATAR ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${widget.userName},',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF16213D),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Let\'s organize your day smarter.',
                        style: TextStyle(
                          color: Color(0xFF50607D),
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildComplexAvatar(),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            const SizedBox(height: 20),

            // 2. --- AI ASSISTANT SECTION (DESIGN ORIGINAL COMPLEXE) ---
            _buildFullAICard(isCompact),

            const SizedBox(height: 20),

            // 3. --- QUICK INFO CARDS ---
            Row(
              children: [
                Expanded(
                  child: _QuickInfoCard(
                    icon: Icons.calendar_month_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    title: 'Next Class',
                    line1: 'Math Analysis',
                    line2: '10:00 AM - 204',
                    onTap: () => widget.onNavigate('emploi'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickInfoCard(
                    icon: Icons.check_circle_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: 'Tasks',
                    line1: '3 tasks',
                    line2: 'remaining today',
                    largeStat: true,
                    onTap: () => widget.onNavigate('tasks'),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: _QuickInfoCard(
                    icon: Icons.tips_and_updates_rounded,
                    iconColor: Color(0xFFF59E0B),
                    title: 'Study Tip',
                    line1: 'Active Recall',
                    line2: 'Try flashcards',
                  ),
                ),
              ],
            ),

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
    );
  }

  // --- WIDGETS DE CONSTRUCTION DÉTAILLÉS ---

  Widget _buildComplexAvatar() {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFE8EEF9)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD6DEEE), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x14233A70), blurRadius: 14, offset: Offset(0, 8)),
        ],
      ),
      child: const Icon(Icons.person_rounded, color: Color(0xFF5E6B87), size: 28),
    );
  }

  Widget _buildFullAICard(bool isCompact) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE4F3FF), Color(0xFFEAE7FF), Color(0xFFFFE8EF)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
        boxShadow: const [
          BoxShadow(color: Color(0x1D304B9D), blurRadius: 40, offset: Offset(0, 20)),
        ],
      ),
      child: Column(
        children: [
          // Illustration avec Stack (Design Original)
          _buildAIIllustration(isCompact),
          const SizedBox(height: 18),
          const Text(
            'AI Study Assistant',
            style: TextStyle(
              color: Color(0xFF1A2746),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask me to summarize, plan or help with exercises',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF526285), fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 20),
          // Input
          _buildAIInput(),
          const SizedBox(height: 15),
          // Chips
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8, runSpacing: 10,
            children: suggestedPrompts.map((p) => _buildSuggestionChip(p)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAIIllustration(bool isCompact) {
    return Container(
      width: double.infinity,
      height: isCompact ? 150 : 165,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFBDE9FF), Color(0xFFD1D6FF), Color(0xFFE6D0FF)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Center(child: _AssistantRobotIcon()),
    );
  }

  Widget _buildAIInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              decoration: const InputDecoration(
                hintText: 'Type your question...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Color(0xFF94A3B8)),
              ),
              onSubmitted: (_) => _submitPrompt(),
            ),
          ),
          GestureDetector(
            onTap: _submitPrompt,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD8E2F7)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _HeaderIcon(icon: Icons.event_note_rounded, color: Color(0xFFF97316)),
              SizedBox(width: 10),
              Text('Today\'s Schedule', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B), fontSize: 16)),
            ],
          ),
          const SizedBox(height: 15),
          const _ScheduleRow(time: '11:00 AM', title: 'Deep Work: Math', subtitle: 'Focus on Calculus', iconColor: Color(0xFF38BDF8)),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          const _ScheduleRow(time: '02:30 PM', title: 'English Lecture', subtitle: 'Hall B - Room 12', iconColor: Color(0xFF22C55E)),
        ],
      ),
    );
  }

  Widget _buildLastPromptCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Last interaction', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _lastPrompt,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
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

class _AssistantRobotIcon extends StatelessWidget {
  const _AssistantRobotIcon();
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Cercle de fond
        Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle)),
        // Robot
        const Icon(Icons.smart_toy_rounded, size: 80, color: Color(0xFF1D3E88)),
        // Étoiles
        const Positioned(top: 10, right: 10, child: Icon(Icons.auto_awesome, color: Colors.white, size: 24)),
        const Positioned(bottom: 20, left: 0, child: Icon(Icons.auto_awesome, color: Colors.white, size: 16)),
      ],
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  const AppCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: child,
    );
  }
}

class _QuickInfoCard extends StatelessWidget {
  final IconData icon; final Color iconColor; final String title; final String line1; final String line2; final VoidCallback? onTap; final bool largeStat;
  const _QuickInfoCard({required this.icon, required this.iconColor, required this.title, required this.line1, required this.line2, this.onTap, this.largeStat = false});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text(line1, style: TextStyle(fontSize: largeStat ? 14 : 12, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
            Text(line2, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final String time; final String title; final String subtitle; final Color iconColor;
  const _ScheduleRow({required this.time, required this.title, required this.subtitle, required this.iconColor});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 70,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text(time, style: TextStyle(color: iconColor, fontWeight: FontWeight.w800, fontSize: 11))),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B), fontSize: 14)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon; final Color color;
  const _HeaderIcon({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
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
      width: active ? 22 : 8, height: 8,
      decoration: BoxDecoration(color: active ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)),
    );
  }
}