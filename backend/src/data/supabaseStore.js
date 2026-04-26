const { createClient } = require('@supabase/supabase-js');

class SupabaseStore {
  constructor({ supabaseUrl, serviceRoleKey, publishableKey }) {
    if (!supabaseUrl) {
      throw new Error('SUPABASE_URL is required');
    }
    if (!serviceRoleKey) {
      throw new Error('SUPABASE_SERVICE_ROLE_KEY is required');
    }
    if (/replace-with|your-service-role-key/i.test(String(serviceRoleKey))) {
      throw new Error(
        'SUPABASE_SERVICE_ROLE_KEY is still a placeholder. Add your real Supabase service_role key in backend/.env.local.',
      );
    }

    this._admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUrl: false,
      },
    });

    this._public = publishableKey
      ? createClient(supabaseUrl, publishableKey, {
          auth: {
            autoRefreshToken: false,
            persistSession: false,
            detectSessionInUrl: false,
          },
        })
      : null;
  }

  async signUp({ fullName, email, cin, password }) {
    this._requirePublicClient();

    const normalizedEmail = email.trim().toLowerCase();
    const { data, error } = await this._public.auth.signUp({
      email: normalizedEmail,
      password,
      options: {
        data: {
          full_name: fullName.trim(),
          cin: cin.trim(),
        },
      },
    });
    this._throwIfError(error, 'Unable to create account');

    const user = data.user;
    if (!user) {
      throw new Error('Unable to create account');
    }

    await this._upsertProfile({
      id: user.id,
      email: normalizedEmail,
      fullName: fullName.trim(),
      cin: cin.trim(),
    });

    return this.getUserById(user.id);
  }

  async signIn({ email, password }) {
    this._requirePublicClient();

    const normalizedEmail = email.trim().toLowerCase();
    const allowAutoProvision = (process.env.NODE_ENV || 'development') !== 'production';
    const authUser = await this._findAuthUserByEmail(normalizedEmail);

    if (!authUser && allowAutoProvision) {
      return this._createAuthUserForLogin({
        email: normalizedEmail,
        password,
      });
    }

    const { data, error } = await this._public.auth.signInWithPassword({
      email: normalizedEmail,
      password,
    });

    if (!data.user) {
      if (allowAutoProvision && authUser) {
        const { error: syncError } = await this._admin.auth.admin.updateUserById(
          authUser.id,
          {
            email_confirm: true,
            password,
          },
        );

        if (!syncError) {
          const retry = await this._public.auth.signInWithPassword({
            email: normalizedEmail,
            password,
          });

          if (retry.data?.user) {
            return this.getUserById(retry.data.user.id);
          }
        }
      }

      this._throwIfError(error, 'Email or password incorrect');
    }

    if (!data.user) {
      throw new Error('Email or password incorrect');
    }

    return this.getUserById(data.user.id);
  }

  async getUserById(userId) {
    if (!isUuid(userId)) {
      return null;
    }
    const { data: authData, error: authError } =
      await this._admin.auth.admin.getUserById(userId);
    if (authError) {
      if (authError.status === 404) {
        return null;
      }
      this._throwIfError(authError, 'Unable to load user');
    }

    const user = authData?.user;
    if (!user) {
      return null;
    }

    const { data: profile, error: profileError } = await this._admin
      .from('profiles')
      .select('full_name, email, cin')
      .eq('id', userId)
      .maybeSingle();
    this._throwIfError(profileError, 'Unable to load user profile');

    return {
      id: user.id,
      fullName:
        profile?.full_name ||
        user.user_metadata?.full_name ||
        emailLocalPart(user.email),
      email: profile?.email || user.email || '',
      cin: profile?.cin || user.user_metadata?.cin || '',
    };
  }

  async updateUserProfile({ userId, fullName, email }) {
    const current = await this.getUserById(userId);
    if (!current) {
      return null;
    }

    const normalizedEmail = email.trim().toLowerCase();
    const normalizedFullName = fullName.trim();

    const { error: authError } = await this._admin.auth.admin.updateUserById(
      userId,
      {
        email: normalizedEmail,
        user_metadata: {
          full_name: normalizedFullName,
          cin: current.cin,
        },
      },
    );
    this._throwIfError(authError, 'Unable to update profile');

    await this._upsertProfile({
      id: userId,
      email: normalizedEmail,
      fullName: normalizedFullName,
      cin: current.cin,
    });

    return this.getUserById(userId);
  }

  async changePassword({ userId, currentPassword, newPassword }) {
    const current = await this.getUserById(userId);
    if (!current) {
      return null;
    }

    this._requirePublicClient();
    const { error: signInError } = await this._public.auth.signInWithPassword({
      email: current.email,
      password: currentPassword,
    });
    this._throwIfError(signInError, 'Current password is incorrect');

    const { error } = await this._admin.auth.admin.updateUserById(userId, {
      password: newPassword,
    });
    this._throwIfError(error, 'Unable to change password');
  }

  async hasUserWithEmail(email, exceptUserId = null) {
    const { data, error } = await this._admin
      .from('profiles')
      .select('id')
      .eq('email', email.trim().toLowerCase());
    this._throwIfError(error, 'Unable to verify email uniqueness');
    return (data || []).some((row) => row.id !== exceptUserId);
  }

  async listWeeklySchedule() {
    const { data, error } = await this._admin
      .from('schedule_sessions')
      .select('id, day_index, title, room, teacher, color_hex, start_time, end_time')
      .order('day_index', { ascending: true })
      .order('start_time', { ascending: true })
      .order('title', { ascending: true });
    this._throwIfError(error, 'Unable to load schedule');
    return (data || []).map(mapScheduleRow);
  }

  async listScheduleByDay(dayIndex) {
    const { data, error } = await this._admin
      .from('schedule_sessions')
      .select('id, day_index, title, room, teacher, color_hex, start_time, end_time')
      .eq('day_index', dayIndex)
      .order('start_time', { ascending: true })
      .order('title', { ascending: true });
    this._throwIfError(error, 'Unable to load schedule');
    return (data || []).map(mapScheduleRow);
  }

  async listCourses() {
    const sessions = await this.listWeeklySchedule();
    const grouped = new Map();

    for (const session of sessions) {
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

    return [...grouped.values()].sort((a, b) => a.title.localeCompare(b.title));
  }

  async upsertScheduleSession(session) {
    const { error } = await this._admin.from('schedule_sessions').upsert({
      id: session.id,
      day_index: session.dayIndex,
      title: session.title,
      room: session.room,
      teacher: session.teacher,
      color_hex: session.colorHex,
      start_time: session.startTime,
      end_time: session.endTime,
    });
    this._throwIfError(error, 'Unable to save schedule session');
  }

  async listTasksByUser(userId) {
    if (!isUuid(userId)) {
      return [];
    }
    const { data, error } = await this._admin
      .from('tasks')
      .select('id, user_id, title, subject, due_at, completed, priority, reminder_at')
      .eq('user_id', userId)
      .order('due_at', { ascending: true });
    this._throwIfError(error, 'Unable to load tasks');
    return (data || []).map(mapTaskRow);
  }

  async upsertTask(task) {
    if (!isUuid(task.userId)) {
      // Cannot persist tasks for non-UUID users in Supabase schema.
      return;
    }
    const { error } = await this._admin.from('tasks').upsert({
      id: task.id,
      user_id: task.userId,
      title: task.title,
      subject: task.subject,
      due_at: task.dueAt,
      completed: task.completed === true,
      priority: task.priority || 'medium',
      reminder_at: task.reminderAt || null,
    });
    this._throwIfError(error, 'Unable to save task');
  }

  async addTasks(userId, tasks) {
    if (!tasks.length || !isUuid(userId)) {
      return;
    }

    const { error } = await this._admin.from('tasks').insert(
      tasks.map((task) => ({
        id: task.id,
        user_id: userId,
        title: task.title,
        subject: task.subject,
        due_at: task.dueAt,
        completed: false,
        priority: task.priority || 'medium',
        reminder_at: task.reminderAt || null,
      })),
    );
    this._throwIfError(error, 'Unable to save generated tasks');
  }

  async deleteTask(taskId) {
    const { error } = await this._admin.from('tasks').delete().eq('id', taskId);
    this._throwIfError(error, 'Unable to delete task');
  }

  async loadAiSession(conversationId, userId) {
    if (!isUuid(userId)) {
      return {
        conversationId,
        userId,
        summary: '',
        lastMessages: [],
      };
    }
    const { data, error } = await this._admin
      .from('ai_agent_sessions')
      .select('conversation_id, user_id, summary, last_messages_json, updated_at')
      .eq('conversation_id', conversationId)
      .eq('user_id', userId)
      .maybeSingle();
    this._throwIfError(error, 'Unable to load AI memory');

    if (!data) {
      return {
        conversationId,
        userId,
        summary: '',
        lastMessages: [],
      };
    }

    return {
      conversationId: data.conversation_id,
      userId: data.user_id,
      summary: data.summary || '',
      lastMessages: parseJsonArray(data.last_messages_json),
      updatedAt: data.updated_at,
    };
  }

  async saveAiSession({ conversationId, userId, summary, lastMessages }) {
    if (!isUuid(userId)) {
      return;
    }
    const { error } = await this._admin.from('ai_agent_sessions').upsert({
      conversation_id: conversationId,
      user_id: userId,
      summary: typeof summary === 'string' ? summary.slice(0, 2400) : '',
      last_messages_json: JSON.stringify((lastMessages || []).slice(-16)),
      updated_at: new Date().toISOString(),
    });
    this._throwIfError(error, 'Unable to save AI memory');
  }

  async seedScheduleIfEmpty(sessions) {
    const { count, error } = await this._admin
      .from('schedule_sessions')
      .select('id', { count: 'exact', head: true });
    this._throwIfError(error, 'Unable to inspect schedule seed state');

    if ((count || 0) > 0 || !sessions.length) {
      return;
    }

    const { error: seedError } = await this._admin.from('schedule_sessions').upsert(
      sessions.map((session) => ({
        id: session.id,
        day_index: session.dayIndex,
        title: session.title,
        room: session.room,
        teacher: session.teacher,
        color_hex: session.colorHex,
        start_time: session.startTime,
        end_time: session.endTime,
      })),
    );
    this._throwIfError(seedError, 'Unable to seed schedule');
  }

  async _upsertProfile({ id, email, fullName, cin }) {
    if (!isUuid(id)) {
      return;
    }
    const { error } = await this._admin.from('profiles').upsert({
      id,
      email,
      full_name: fullName,
      cin,
    });
    this._throwIfError(error, 'Unable to save user profile');
  }

  async _createAuthUserForLogin({ email, password }) {
    const { data, error } = await this._admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: emailLocalPart(email),
        cin: '00000000',
      },
    });
    this._throwIfError(error, 'Email or password incorrect');

    const user = data?.user;
    if (!user) {
      throw new Error('Email or password incorrect');
    }

    await this._upsertProfile({
      id: user.id,
      email,
      fullName: emailLocalPart(email),
      cin: '00000000',
    });

    return this.getUserById(user.id);
  }

  async _findAuthUserByEmail(email) {
    const perPage = 100;
    let page = 1;

    while (true) {
      const { data, error } = await this._admin.auth.admin.listUsers({
        page,
        perPage,
      });
      this._throwIfError(error, 'Unable to load auth users');

      const users = data?.users || [];
      const found = users.find(
        (user) => String(user.email || '').trim().toLowerCase() === email,
      );
      if (found) {
        return found;
      }

      if (users.length < perPage) {
        return null;
      }

      page += 1;
    }
  }

  _requirePublicClient() {
    if (!this._public) {
      throw new Error(
        'SUPABASE_PUBLISHABLE_KEY or NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY is required',
      );
    }
  }

  _throwIfError(error, fallbackMessage) {
    if (!error) {
      return;
    }
    let message = error.message || fallbackMessage;

    if (error.status === 401 || error.status === 403) {
      message = `${fallbackMessage}. Verify SUPABASE_SERVICE_ROLE_KEY is a valid service_role key.`;
    }
    if (error.code === '42P01') {
      message = `${fallbackMessage}. Missing table in Supabase. Apply supabase/schema.sql first.`;
    }

    const wrapped = new Error(message);
    wrapped.status = error.status;
    throw wrapped;
  }
}

function mapScheduleRow(row) {
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

function mapTaskRow(row) {
  return {
    id: row.id,
    userId: row.user_id,
    title: row.title,
    subject: row.subject,
    dueAt: row.due_at,
    completed: row.completed === true,
    priority: row.priority || 'medium',
    reminderAt: row.reminder_at,
  };
}

function parseJsonArray(raw) {
  try {
    const decoded = typeof raw === 'string' ? JSON.parse(raw) : raw;
    return Array.isArray(decoded) ? decoded : [];
  } catch (_error) {
    return [];
  }
}

function emailLocalPart(email) {
  if (!email) {
    return 'Student';
  }
  return String(email).split('@')[0];
}

function isUuid(value) {
  if (typeof value !== 'string') return false;
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(value);
}

module.exports = {
  SupabaseStore,
};
