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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        toolbarHeight: 86,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_note_rounded),
                SizedBox(width: 10),
                Text(
                  'Emploi du Temps',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'Weekly classes, rooms, teachers, and conflicts',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh schedule',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
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
    final selectedSessions = sessionsByDay[selectedDayIndex];
    final now = DateTime.now();
    final currentSession = _currentSession(sessions, now);
    final nextSession = _nextSession(selectedSessions, now);

    return Column(
      children: [
        const SizedBox(height: 12),
        _DaySelector(
          sessionsByDay: sessionsByDay,
          selectedDayIndex: selectedDayIndex,
          onDaySelected: onDaySelected,
        ),
        const SizedBox(height: 12),
        _DaySummary(
          dayName: scheduleDayNames[selectedDayIndex],
          sessions: selectedSessions,
          currentSession: currentSession,
          nextSession: nextSession,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: PageView.builder(
            controller: pageController,
            itemCount: scheduleDayLabels.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, dayIndex) {
              final daySessions = sessionsByDay[dayIndex];
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: _DayScheduleList(
                  sessions: daySessions,
                  currentSession: currentSession,
                  nextSession: _nextSession(daySessions, now),
                ),
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

  static ScheduleSession? _currentSession(
    List<ScheduleSession> sessions,
    DateTime now,
  ) {
    for (final session in sessions) {
      if (session.isCurrentAt(now)) {
        return session;
      }
    }
    return null;
  }

  static ScheduleSession? _nextSession(
    List<ScheduleSession> sessions,
    DateTime now,
  ) {
    for (final session in sessions) {
      if (session.startsAfter(now)) {
        return session;
      }
    }
    return null;
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.sessionsByDay,
    required this.selectedDayIndex,
    required this.onDaySelected,
  });

  final List<List<ScheduleSession>> sessionsByDay;
  final int selectedDayIndex;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: scheduleDayLabels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = selectedDayIndex == index;
          return _DayChip(
            label: scheduleDayLabels[index],
            count: sessionsByDay[index].length,
            selected: selected,
            onTap: () => onDaySelected(index),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F172033),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF1E293B),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: TextStyle(
                color: selected ? Colors.white70 : const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({
    required this.dayName,
    required this.sessions,
    required this.currentSession,
    required this.nextSession,
  });

  final String dayName;
  final List<ScheduleSession> sessions;
  final ScheduleSession? currentSession;
  final ScheduleSession? nextSession;

  @override
  Widget build(BuildContext context) {
    final conflicts = _countConflicts(sessions);
    final status = currentSession != null
        ? 'Now: ${currentSession!.displayTitle}'
        : nextSession != null
        ? 'Next: ${nextSession!.displayTitle}'
        : 'No more classes today';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: Color(0xFF2563EB),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dayName • ${sessions.length} classes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (conflicts > 0) ...[
            const SizedBox(width: 8),
            _StatusPill(
              label: '$conflicts overlap',
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFEA580C),
            ),
          ],
        ],
      ),
    );
  }

  int _countConflicts(List<ScheduleSession> sessions) {
    var count = 0;
    for (var index = 0; index < sessions.length; index++) {
      final current = sessions[index];
      final hasConflict = sessions.any(current.overlaps);
      if (hasConflict) {
        count++;
      }
    }
    return count;
  }
}

class _DayScheduleList extends StatelessWidget {
  const _DayScheduleList({
    required this.sessions,
    required this.currentSession,
    required this.nextSession,
  });

  final List<ScheduleSession> sessions;
  final ScheduleSession? currentSession;
  final ScheduleSession? nextSession;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 120),
        children: const [_EmptyScheduleState()],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final session = sessions[index];
        final hasConflict = sessions.any(session.overlaps);
        return _SessionCard(
          session: session,
          isCurrent: currentSession?.id == session.id,
          isNext: nextSession?.id == session.id,
          hasConflict: hasConflict,
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.isCurrent,
    required this.isNext,
    required this.hasConflict,
  });

  final ScheduleSession session;
  final bool isCurrent;
  final bool isNext;
  final bool hasConflict;

  @override
  Widget build(BuildContext context) {
    final accent = Color(session.colorValue);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent
              ? accent.withValues(alpha: 0.45)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? accent.withValues(alpha: 0.18)
                : const Color(0x0F172033),
            blurRadius: isCurrent ? 18 : 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TimeBadge(
                          start: _formatTime(session.start),
                          end: _formatTime(session.end),
                          color: accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _StatusPill(
                                    label: session.category,
                                    icon: Icons.school_rounded,
                                    color: accent,
                                  ),
                                  if (isCurrent)
                                    _StatusPill(
                                      label: 'Now',
                                      icon: Icons.play_circle_rounded,
                                      color: const Color(0xFF16A34A),
                                    ),
                                  if (isNext)
                                    _StatusPill(
                                      label: 'Next',
                                      icon: Icons.arrow_forward_rounded,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  if (hasConflict)
                                    _StatusPill(
                                      label: 'Overlap',
                                      icon: Icons.warning_amber_rounded,
                                      color: const Color(0xFFEA580C),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                session.displayTitle,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _SessionMeta(
                          icon: Icons.location_on_outlined,
                          label: session.room,
                        ),
                        _SessionMeta(
                          icon: Icons.person_outline_rounded,
                          label: session.teacher,
                        ),
                        _SessionMeta(
                          icon: Icons.timer_outlined,
                          label: _formatDuration(session.duration),
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

class _TimeBadge extends StatelessWidget {
  const _TimeBadge({
    required this.start,
    required this.end,
    required this.color,
  });

  final String start;
  final String end;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            start,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            end,
            style: TextStyle(
              color: color.withValues(alpha: 0.82),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionMeta extends StatelessWidget {
  const _SessionMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 230),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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

String _formatDuration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes % 60;
  if (hours == 0) {
    return '${minutes}m';
  }
  if (minutes == 0) {
    return '${hours}h';
  }
  return '${hours}h ${minutes}m';
}
