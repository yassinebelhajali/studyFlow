class InMemoryStore {
  constructor() {
    this._profiles = new Map();
    this._scheduleSessions = [];
    this._tasks = [];
    this._aiSessions = new Map();
  }

  async signUp({ fullName, email, cin, password }) {
    const normalizedEmail = email.trim().toLowerCase();
    if ([...this._profiles.values()].some((profile) => profile.email === normalizedEmail)) {
      const error = new Error('An account already exists for this email');
      error.status = 409;
      throw error;
    }

    const user = {
      id: `user-${this._profiles.size + 1}`,
      fullName: fullName.trim(),
      email: normalizedEmail,
      cin: cin.trim(),
      password,
    };
    this._profiles.set(user.id, user);
    return this.getUserById(user.id);
  }

  async signIn({ email, password }) {
    const normalizedEmail = email.trim().toLowerCase();
    const user = [...this._profiles.values()].find(
      (item) => item.email === normalizedEmail && item.password === password,
    );
    if (!user) {
      const error = new Error('Email or password incorrect');
      error.status = 401;
      throw error;
    }
    return this.getUserById(user.id);
  }

  async getUserById(userId) {
    const user = this._profiles.get(userId);
    if (!user) {
      return null;
    }
    return {
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      cin: user.cin,
    };
  }

  async updateUserProfile({ userId, fullName, email }) {
    const user = this._profiles.get(userId);
    if (!user) {
      return null;
    }
    user.fullName = fullName.trim();
    user.email = email.trim().toLowerCase();
    return this.getUserById(userId);
  }

  async changePassword({ userId, currentPassword, newPassword }) {
    const user = this._profiles.get(userId);
    if (!user) {
      return null;
    }
    if (user.password !== currentPassword) {
      const error = new Error('Current password is incorrect');
      error.status = 401;
      throw error;
    }
    user.password = newPassword;
  }

  async hasUserWithEmail(email, exceptUserId = null) {
    const normalizedEmail = email.trim().toLowerCase();
    return [...this._profiles.values()].some(
      (user) => user.email === normalizedEmail && user.id !== exceptUserId,
    );
  }

  async listWeeklySchedule() {
    return [...this._scheduleSessions].sort(compareSchedule);
  }

  async listScheduleByDay(dayIndex) {
    return this._scheduleSessions.filter((item) => item.dayIndex === dayIndex).sort(compareSchedule);
  }

  async listCourses() {
    const grouped = new Map();
    for (const session of this._scheduleSessions) {
      const key = `${session.title}::${session.room}::${session.teacher}::${session.colorHex}`;
      const existing = grouped.get(key);
      if (existing) {
        existing.sessionsCount += 1;
      } else {
        grouped.set(key, {
          title: session.title,
          room: session.room,
          teacher: session.teacher,
          colorHex: session.colorHex,
          sessionsCount: 1,
        });
      }
    }
    return [...grouped.values()];
  }

  async upsertScheduleSession(session) {
    const index = this._scheduleSessions.findIndex((item) => item.id === session.id);
    if (index >= 0) {
      this._scheduleSessions[index] = { ...session };
    } else {
      this._scheduleSessions.push({ ...session });
    }
  }

  async listTasksByUser(userId) {
    return this._tasks.filter((task) => task.userId === userId);
  }

  async upsertTask(task) {
    const index = this._tasks.findIndex((item) => item.id === task.id);
    if (index >= 0) {
      this._tasks[index] = { ...task };
    } else {
      this._tasks.push({ ...task });
    }
  }

  async addTasks(userId, tasks) {
    for (const task of tasks) {
      this._tasks.push({ ...task, userId });
    }
  }

  async deleteTask(taskId) {
    this._tasks = this._tasks.filter((task) => task.id !== taskId);
  }

  async loadAiSession(conversationId, userId) {
    return (
      this._aiSessions.get(`${conversationId}::${userId}`) || {
        conversationId,
        userId,
        summary: '',
        lastMessages: [],
      }
    );
  }

  async saveAiSession(session) {
    this._aiSessions.set(`${session.conversationId}::${session.userId}`, {
      ...session,
      updatedAt: new Date().toISOString(),
    });
  }

  async seedScheduleIfEmpty(sessions) {
    if (this._scheduleSessions.length > 0) {
      return;
    }
    this._scheduleSessions = sessions.map((session) => ({ ...session }));
  }

  seedSession(session) {
    this._scheduleSessions.push({ ...session });
  }
}

function compareSchedule(a, b) {
  if (a.dayIndex !== b.dayIndex) {
    return a.dayIndex - b.dayIndex;
  }
  if (a.startTime !== b.startTime) {
    return a.startTime.localeCompare(b.startTime);
  }
  return a.title.localeCompare(b.title);
}

module.exports = {
  InMemoryStore,
};
