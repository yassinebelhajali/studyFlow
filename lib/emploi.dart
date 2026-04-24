import 'dart:async';

import 'package:flutter/material.dart';

import 'core/notifications/study_notification_scheduler.dart';
import 'data/schedule/schedule_seed.dart';
import 'domain/models/schedule_session.dart';
import 'domain/repositories/schedule_repository.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({
    super.key,
    required this.repository,
    required this.notificationScheduler,
  });

  final ScheduleRepository repository;
  final StudyNotificationScheduler notificationScheduler;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late final PageController _pageController;
  late Future<List<ScheduleSession>> _sessionsFuture;
  late int selectedDayIndex;

  @override
  void initState() {
    super.initState();
    selectedDayIndex = _initialDayIndex();
    _pageController = PageController(initialPage: selectedDayIndex);
    _sessionsFuture = _loadScheduleAndSyncReminders();
  }

  @override
  void didUpdateWidget(covariant SchedulePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.notificationScheduler != widget.notificationScheduler) {
      _sessionsFuture = _loadScheduleAndSyncReminders();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = _loadScheduleAndSyncReminders();
    setState(() {
      _sessionsFuture = future;
    });
    await future;
  }

  Future<List<ScheduleSession>> _loadScheduleAndSyncReminders() async {
    final sessions = await widget.repository.getWeeklySchedule();
    unawaited(
      widget.notificationScheduler
          .syncClassReminders(sessions)
          .catchError((_) {}),
    );
    return sessions;
  }

  static int _initialDayIndex() {
    final weekday = DateTime.now().weekday - 1;
    if (weekday < 0 || weekday >= scheduleDayLabels.length) {
      return 0;
    }
    return weekday;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDF2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F9AE7),
        surfaceTintColor: const Color(0xFF2F9AE7),
        foregroundColor: Colors.white,
        toolbarHeight: isWide ? 112 : 94,
        titleSpacing: isWide ? 22 : 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: isWide ? 32 : 26),
                SizedBox(width: isWide ? 12 : 10),
                Text(
                  'Emploi du Temps',
                  style: TextStyle(
                    fontSize: isWide ? 30 : 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: isWide ? 7 : 4),
            Text(
              'Your weekly schedule',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isWide ? 14 : 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<ScheduleSession>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ScheduleErrorState(onRetry: _refresh);
          }

          final sessions = snapshot.data ?? [];
          return _ScheduleContent(
            sessions: sessions,
            pageController: _pageController,
            selectedDayIndex: selectedDayIndex,
            onDaySelected: (index) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            },
            onPageChanged: (index) {
              setState(() {
                selectedDayIndex = index;
              });
            },
            onRefresh: _refresh,
          );
        },
      ),
    );
  }
}

class _ScheduleContent extends StatelessWidget {
  const _ScheduleContent({
    required this.sessions,
    required this.pageController,
    required this.selectedDayIndex,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.onRefresh,
  });

  final List<ScheduleSession> sessions;
  final PageController pageController;
  final int selectedDayIndex;
  final ValueChanged<int> onDaySelected;
  final ValueChanged<int> onPageChanged;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final sessionsByDay = _groupSessionsByDay(sessions);

    return Column(
      children: [
        const SizedBox(height: 14),
        _DaySelector(
          selectedDayIndex: selectedDayIndex,
          onDaySelected: onDaySelected,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: PageView.builder(
            controller: pageController,
            itemCount: scheduleDayLabels.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, dayIndex) {
              final daySessions = sessionsByDay[dayIndex];
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: _DayScheduleList(sessions: daySessions),
              );
            },
          ),
        ),
      ],
    );
  }

  static List<List<ScheduleSession>> _groupSessionsByDay(
    List<ScheduleSession> sessions,
  ) {
    final grouped = List.generate(scheduleDayLabels.length, (_) {
      return <ScheduleSession>[];
    });

    for (final session in sessions) {
      if (session.dayIndex >= 0 && session.dayIndex < grouped.length) {
        grouped[session.dayIndex].add(session);
      }
    }

    for (final daySessions in grouped) {
      daySessions.sort((a, b) => a.start.compareTo(b.start));
    }

    return grouped;
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.selectedDayIndex,
    required this.onDaySelected,
  });

  final int selectedDayIndex;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 600;

    return SizedBox(
      height: isWide ? 66 : 58,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: isWide ? 16 : 14),
        scrollDirection: Axis.horizontal,
        itemCount: scheduleDayLabels.length,
        separatorBuilder: (_, _) => SizedBox(width: isWide ? 10 : 8),
        itemBuilder: (context, index) {
          final selected = selectedDayIndex == index;
          return _DayChip(
            label: scheduleDayLabels[index],
            selected: selected,
            onTap: () => onDaySelected(index),
            compact: !isWide,
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: compact ? 78 : 90,
        height: compact ? 46 : 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2D6CDF) : const Color(0xFFF2F2F5),
          borderRadius: BorderRadius.circular(24),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x332D6CDF),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF111111),
            fontWeight: FontWeight.w800,
            fontSize: compact ? 14 : 16,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

class _DayScheduleList extends StatelessWidget {
  const _DayScheduleList({required this.sessions});

  final List<ScheduleSession> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 120),
        children: const [_EmptyScheduleState()],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 6, 16, 120),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _TimelineSessionRow(
          session: session,
          isFirst: index == 0,
          isLast: index == sessions.length - 1,
        );
      },
    );
  }
}

class _TimelineSessionRow extends StatelessWidget {
  const _TimelineSessionRow({
    required this.session,
    required this.isFirst,
    required this.isLast,
  });

  final ScheduleSession session;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final accent = Color(session.colorValue);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 600;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: compact ? 68 : 76,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _formatTime(session.start),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: compact ? 17 : 21,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 22,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: 3,
                      color: isFirst
                          ? Colors.transparent
                          : const Color(0xFFD4D5DA),
                    ),
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 3,
                      color: isLast
                          ? Colors.transparent
                          : const Color(0xFFD4D5DA),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x17000000),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      session.displayTitle,
                      style: TextStyle(
                        color: Color(0xFF111111),
                        fontSize: compact ? 16 : 19,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: const Color(0xFF6E6E72),
                          size: compact ? 22 : 26,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            session.room,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF6E6E72),
                              fontSize: compact ? 14 : 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          color: const Color(0xFF6E6E72),
                          size: compact ? 22 : 26,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            session.teacher,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF6E6E72),
                              fontSize: compact ? 14 : 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyScheduleState extends StatelessWidget {
  const _EmptyScheduleState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            color: Color(0xFF94A3B8),
            size: 42,
          ),
          SizedBox(height: 12),
          Text(
            'No classes scheduled',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Pull down to refresh from the backend.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ScheduleErrorState extends StatelessWidget {
  const _ScheduleErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFF64748B),
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Schedule unavailable',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Check the API server and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(Duration value) {
  final hours = value.inHours.toString().padLeft(2, '0');
  final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
  return '$hours:$minutes';
}
