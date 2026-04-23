function createScheduleTools(db) {
  const listByDay = db.prepare(`
    SELECT id, day_index, title, room, teacher, color_hex, start_time, end_time
    FROM schedule_sessions
    WHERE day_index = ?
    ORDER BY start_time ASC, title ASC
  `);
  const listWeek = db.prepare(`
    SELECT id, day_index, title, room, teacher, color_hex, start_time, end_time
    FROM schedule_sessions
    ORDER BY day_index ASC, start_time ASC, title ASC
  `);

  return [
    {
      name: 'get_today_schedule',
      description:
        'Read the student timetable for a specific day. Use it for schedule, class, room, teacher, or daily planning requests.',
      inputSchema: {
        type: 'object',
        properties: {
          dayIndex: 'optional integer 0-5 where 0=Monday and 5=Saturday. Omit for today.',
        },
      },
      validateInput(input) {
        const dayIndex =
          input.dayIndex === undefined || input.dayIndex === null
            ? null
            : Number(input.dayIndex);
        if (dayIndex !== null && (!Number.isInteger(dayIndex) || dayIndex < 0 || dayIndex > 5)) {
          return { ok: false, error: 'dayIndex must be an integer from 0 to 5' };
        }
        return { ok: true, value: { dayIndex } };
      },
      async execute(input, context) {
        const dayIndex = input.dayIndex ?? weekdayToScheduleIndex(context.now);
        if (dayIndex < 0 || dayIndex > 5) {
          return {
            success: true,
            summary: 'No scheduled classes were found because today is outside the school week.',
            data: { dayIndex, sessions: [] },
          };
        }

        const sessions = listByDay.all(dayIndex).map(toApiSession);
        return {
          success: true,
          summary:
            sessions.length === 0
              ? `No scheduled classes were found for ${dayName(dayIndex)}.`
              : sessions.map(formatSession).join('; '),
          data: { dayIndex, dayName: dayName(dayIndex), sessions },
        };
      },
    },
    {
      name: 'get_weekly_schedule',
      description:
        'Read the complete weekly timetable. Use it when the user asks about the whole week or compares multiple days.',
      inputSchema: { type: 'object', properties: {} },
      validateInput() {
        return { ok: true, value: {} };
      },
      async execute() {
        const sessions = listWeek.all().map(toApiSession);
        return {
          success: true,
          summary: summarizeWeek(sessions),
          data: { sessions },
        };
      },
    },
  ];
}

function weekdayToScheduleIndex(now) {
  const jsDay = now.getDay();
  if (jsDay === 0) {
    return 6;
  }
  return jsDay - 1;
}

function toApiSession(row) {
  return {
    id: row.id,
    dayIndex: row.day_index,
    title: row.title,
    room: row.room,
    teacher: row.teacher,
    colorHex: row.color_hex,
    startTime: row.start_time,
    endTime: row.end_time,
  };
}

function formatSession(session) {
  return `${session.startTime}-${session.endTime} ${session.title} in ${session.room}`;
}

function summarizeWeek(sessions) {
  if (sessions.length === 0) {
    return 'No schedule sessions are currently stored.';
  }

  const byDay = new Map();
  for (const session of sessions) {
    const list = byDay.get(session.dayIndex) || [];
    list.push(formatSession(session));
    byDay.set(session.dayIndex, list);
  }

  return [...byDay.entries()]
    .map(([index, items]) => `${dayName(index)}: ${items.join('; ')}`)
    .join('\n');
}

function dayName(index) {
  return ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][index] || 'Unknown';
}

module.exports = {
  createScheduleTools,
  weekdayToScheduleIndex,
};
