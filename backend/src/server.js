const fs = require('node:fs');
const { randomUUID } = require('node:crypto');
const path = require('node:path');
const crypto = require('node:crypto');

const Database = require('better-sqlite3');
const cors = require('cors');
const express = require('express');

const { AgentController, writeSse } = require('./ai/agentController');
const { LlmReasoningLayer } = require('./ai/llmReasoningLayer');
const { AgentMemoryStore } = require('./ai/memoryStore');
const { ToolRegistry } = require('./ai/toolRegistry');
const { createScheduleTools } = require('./ai/tools/scheduleTools');
const { createStudyPlanningTools } = require('./ai/tools/studyPlanningTools');
const { loadEnvFiles } = require('./config/env');
const logger = require('./logger');

loadEnvFiles();

const app = express();
const port = Number(process.env.PORT || 3000);
const databasePath = path.resolve(
  process.cwd(),
  process.env.DATABASE_PATH || './data/studyflow.sqlite',
);
const corsOrigin = process.env.CORS_ORIGIN || '*';

fs.mkdirSync(path.dirname(databasePath), { recursive: true });

const db = new Database(databasePath);
db.pragma('journal_mode = WAL');
const agentMemoryStore = new AgentMemoryStore(db);
let agentController;

app.use(
  cors({
    origin: corsOrigin === '*' ? true : corsOrigin.split(',').map((item) => item.trim()),
  }),
);
app.use(express.json({ limit: '32kb' }));

// Request/response logging middleware
app.use((request, response, next) => {
  const elapsed = logger.startTimer();
  const { method, path: reqPath } = request;

  response.on('finish', () => {
    const level = response.statusCode >= 500 ? 'error' : response.statusCode >= 400 ? 'warn' : 'info';
    logger[level]('http.request', {
      method,
      path: reqPath,
      status: response.statusCode,
      durationMs: elapsed(),
      ip: request.ip,
    });
  });

  next();
});

initializeDatabase();
agentMemoryStore.initialize();
seedScheduleIfEmpty();
agentController = new AgentController({
  llm: new LlmReasoningLayer(process.env),
  tools: new ToolRegistry([
    ...createScheduleTools(db),
    ...createStudyPlanningTools(db),
  ]),
  memoryStore: agentMemoryStore,
});

app.get('/health', (_request, response) => {
  response.json({ ok: true });
});

app.post('/api/auth/signup', (request, response) => {
  const validation = validateAuthRequest(request.body);
  if (!validation.ok) {
    return response.status(400).json({ error: validation.error });
  }

  const { fullName, email, cin, password } = validation.value;
  const passwordHash = hashPassword(password);
  const normalizedEmail = email.toLowerCase();
  const existingUser = db
    .prepare('SELECT id FROM users WHERE lower(email) = lower(?)')
    .get(normalizedEmail);

  if (existingUser) {
    return response
      .status(409)
      .json({ error: 'An account already exists for this email' });
  }

  const user = {
    id: crypto.randomUUID(),
    fullName,
    email: normalizedEmail,
    cin,
    passwordHash,
  };

  db.prepare(
    `INSERT INTO users (id, full_name, email, cin, password_hash)
     VALUES (@id, @fullName, @email, @cin, @passwordHash)`,
  ).run(user);

  return response.status(201).json(toApiUser(user));
});

app.post('/api/auth/signin', (request, response) => {
  const validation = validateSignInRequest(request.body);
  if (!validation.ok) {
    return response.status(400).json({ error: validation.error });
  }

  const { email, password } = validation.value;
  const user = db
    .prepare(
      `SELECT id, full_name AS fullName, email, cin, password_hash AS passwordHash
       FROM users
       WHERE lower(email) = lower(?)`,
    )
    .get(email.toLowerCase());

  if (!user || user.passwordHash !== hashPassword(password)) {
    return response.status(401).json({ error: 'Email or password incorrect' });
  }

  return response.json(toApiUser(user));
});

app.get('/api/auth/users/:id', (request, response) => {
  const userId = String(request.params.id || '').trim();
  if (!userId) {
    return response.status(400).json({ error: 'User id is required' });
  }

  const user = db
    .prepare(
      `SELECT id, full_name AS fullName, email, cin
       FROM users
       WHERE id = ?`,
    )
    .get(userId);

  if (!user) {
    return response.status(404).json({ error: 'User not found' });
  }

  return response.json(user);
});

app.patch('/api/auth/users/:id', (request, response) => {
  const userId = String(request.params.id || '').trim();
  if (!userId) {
    return response.status(400).json({ error: 'User id is required' });
  }

  const validation = validateProfileUpdateRequest(request.body);
  if (!validation.ok) {
    return response.status(400).json({ error: validation.error });
  }

  const existingUser = db
    .prepare('SELECT id, cin FROM users WHERE id = ?')
    .get(userId);
  if (!existingUser) {
    return response.status(404).json({ error: 'User not found' });
  }

  const duplicate = db
    .prepare('SELECT id FROM users WHERE lower(email) = lower(?) AND id != ?')
    .get(validation.value.email, userId);
  if (duplicate) {
    return response
      .status(409)
      .json({ error: 'An account already exists for this email' });
  }

  db.prepare(
    `UPDATE users
     SET full_name = ?, email = ?
     WHERE id = ?`,
  ).run(validation.value.fullName, validation.value.email, userId);

  return response.json({
    id: userId,
    fullName: validation.value.fullName,
    email: validation.value.email,
    cin: existingUser.cin,
  });
});

app.patch('/api/auth/users/:id/password', (request, response) => {
  const userId = String(request.params.id || '').trim();
  if (!userId) {
    return response.status(400).json({ error: 'User id is required' });
  }

  const validation = validatePasswordChangeRequest(request.body);
  if (!validation.ok) {
    return response.status(400).json({ error: validation.error });
  }

  const existingUser = db
    .prepare('SELECT id, password_hash AS passwordHash FROM users WHERE id = ?')
    .get(userId);
  if (!existingUser) {
    return response.status(404).json({ error: 'User not found' });
  }

  if (existingUser.passwordHash !== hashPassword(validation.value.currentPassword)) {
    return response.status(401).json({ error: 'Current password is incorrect' });
  }

  db.prepare(
    `UPDATE users
     SET password_hash = ?
     WHERE id = ?`,
  ).run(hashPassword(validation.value.newPassword), userId);

  return response.status(204).send();
});

app.get('/api/schedule', (_request, response) => {
  const rows = db
    .prepare(
      `SELECT id, day_index, title, room, teacher, color_hex, start_time, end_time
       FROM schedule_sessions
       ORDER BY day_index ASC, start_time ASC, title ASC`,
    )
    .all();

  response.json(rows.map(toApiSession));
});

app.get('/api/courses', (_request, response) => {
  const rows = db
    .prepare(
      `SELECT title, room, teacher, color_hex, COUNT(*) as sessions_count
       FROM schedule_sessions
       GROUP BY title, room, teacher, color_hex
       ORDER BY title ASC`,
    )
    .all();

  response.json(rows.map(row => ({
    title: row.title,
    room: row.room,
    teacher: row.teacher,
    colorHex: row.color_hex,
    sessionsCount: row.sessions_count,
  })));
});

app.post('/api/schedule', requireAdminToken, (request, response) => {
  const validation = validateSession(request.body);
  if (!validation.ok) {
    return response.status(400).json({ error: validation.error });
  }

  const session = validation.value;
  db.prepare(
    `INSERT INTO schedule_sessions
      (id, day_index, title, room, teacher, color_hex, start_time, end_time)
     VALUES
      (@id, @dayIndex, @title, @room, @teacher, @colorHex, @startTime, @endTime)
     ON CONFLICT(id) DO UPDATE SET
      day_index = excluded.day_index,
      title = excluded.title,
      room = excluded.room,
      teacher = excluded.teacher,
      color_hex = excluded.color_hex,
      start_time = excluded.start_time,
      end_time = excluded.end_time`,
  ).run(session);

  return response.status(201).json(session);
});

app.get('/api/tasks', (request, response) => {
  const userId = request.query.userId;
  if (!userId) return response.status(400).json({ error: 'userId is required' });

  const rows = db
    .prepare(
      `SELECT id, title, subject, due_at AS dueAt, completed, reminder_at AS reminderAt
       FROM tasks
       WHERE user_id = ?
       ORDER BY due_at ASC`,
    )
    .all(userId);

  response.json(rows.map(row => ({
    ...row,
    completed: !!row.completed
  })));
});

app.post('/api/tasks', (request, response) => {
  const { id, userId, title, subject, dueAt, completed, reminderAt } = request.body;
  if (!userId || !title || !dueAt) {
    return response.status(400).json({ error: 'userId, title, and dueAt are required' });
  }

  db.prepare(
    `INSERT INTO tasks (id, user_id, title, subject, due_at, completed, reminder_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       title = excluded.title,
       subject = excluded.subject,
       due_at = excluded.due_at,
       completed = excluded.completed,
       reminder_at = excluded.reminder_at`,
  ).run(id || crypto.randomUUID(), userId, title, subject || 'General', dueAt, completed ? 1 : 0, reminderAt);

  response.status(201).json({ id, success: true });
});

app.delete('/api/tasks/:id', (request, response) => {
  db.prepare('DELETE FROM tasks WHERE id = ?').run(request.params.id);
  response.status(204).send();
});

app.post(
  '/api/ai/chat',
  asyncHandler(async (request, response) => {
    const validation = validateAiRequest(request.body, 'chat');
    if (!validation.ok) {
      return response.status(400).json(buildAiError(validation.error));
    }

    try {
      const run = await agentController.completeChat(validation.value);
      return response.json(buildAiSuccess('chat', validation.value, run));
    } catch (error) {
      logger.error('ai.chat.failed', {
        conversationId: validation.value.conversationId,
        requestId: validation.value.requestId,
        error: error.message,
      });
      return response.status(aiHttpStatus(error)).json(buildAiFailure(error, validation.value));
    }
  }),
);

app.post(
  '/api/ai/agent',
  asyncHandler(async (request, response) => {
    const validation = validateAiRequest(request.body, 'agent');
    if (!validation.ok) {
      return response.status(400).json(buildAiError(validation.error));
    }

    try {
      const run = await agentController.completeAgent(validation.value);
      return response.json(buildAiSuccess('agent', validation.value, run));
    } catch (error) {
      logger.error('ai.agent.failed', {
        conversationId: validation.value.conversationId,
        requestId: validation.value.requestId,
        error: error.message,
      });
      return response.status(aiHttpStatus(error)).json(buildAiFailure(error, validation.value));
    }
  }),
);

app.post('/api/ai/chat/stream', async (request, response) => {
  const validation = validateAiRequest(request.body, 'chat');
  if (!validation.ok) {
    return response.status(400).json(buildAiError(validation.error));
  }

  response.writeHead(200, {
    'Content-Type': 'text/event-stream; charset=utf-8',
    'Cache-Control': 'no-cache, no-transform',
    Connection: 'keep-alive',
  });

  const sseElapsed = logger.startTimer();
  logger.info('sse.stream.start', { conversationId: validation.value.conversationId, mode: 'chat' });
  try {
    writeSse(response, {
      event: 'meta',
      requestId: validation.value.requestId,
      mode: 'chat',
      conversationId: validation.value.conversationId,
      done: false,
    });
    await agentController.streamChat(validation.value, response);
    writeSse(response, {
      event: 'done',
      requestId: validation.value.requestId,
      mode: 'chat',
      conversationId: validation.value.conversationId,
      done: true,
    });
    logger.info('sse.stream.done', { conversationId: validation.value.conversationId, mode: 'chat', durationMs: sseElapsed() });
  } catch (error) {
    logger.error('sse.stream.failed', { conversationId: validation.value.conversationId, mode: 'chat', durationMs: sseElapsed(), error: error.message });
    writeSse(response, {
      event: 'error',
      error: buildAiStreamError(error),
    });
    writeSse(response, {
      event: 'done',
      requestId: validation.value.requestId,
      mode: 'chat',
      conversationId: validation.value.conversationId,
      done: true,
    });
  } finally {
    response.end();
  }
});

app.post('/api/ai/agent/stream', async (request, response) => {
  const validation = validateAiRequest(request.body, 'agent');
  if (!validation.ok) {
    return response.status(400).json(buildAiError(validation.error));
  }

  response.writeHead(200, {
    'Content-Type': 'text/event-stream; charset=utf-8',
    'Cache-Control': 'no-cache, no-transform',
    Connection: 'keep-alive',
  });

  const sseElapsed = logger.startTimer();
  logger.info('sse.stream.start', { conversationId: validation.value.conversationId, mode: 'agent' });
  try {
    writeSse(response, {
      event: 'meta',
      requestId: validation.value.requestId,
      mode: 'agent',
      conversationId: validation.value.conversationId,
      done: false,
    });
    await agentController.streamAgent(validation.value, response);
    writeSse(response, {
      event: 'done',
      requestId: validation.value.requestId,
      mode: 'agent',
      conversationId: validation.value.conversationId,
      done: true,
    });
    logger.info('sse.stream.done', { conversationId: validation.value.conversationId, mode: 'agent', durationMs: sseElapsed() });
  } catch (error) {
    logger.error('sse.stream.failed', { conversationId: validation.value.conversationId, mode: 'agent', durationMs: sseElapsed(), error: error.message });
    writeSse(response, {
      event: 'error',
      error: buildAiStreamError(error),
    });
    writeSse(response, {
      event: 'done',
      requestId: validation.value.requestId,
      mode: 'agent',
      conversationId: validation.value.conversationId,
      done: true,
    });
  } finally {
    response.end();
  }
});

app.use((error, _request, response, _next) => {
  logger.error('http.unhandled_error', { error: error.message, stack: error.stack });
  response.status(500).json({ error: 'Internal server error' });
});

app.listen(port, () => {
  logger.info('server.started', {
    port,
    env: process.env.NODE_ENV || 'development',
    llmProvider: process.env.LLM_PROVIDER || 'mock',
    llmModel: process.env.GEMINI_MODEL || process.env.LLM_MODEL || '(none)',
    llmTimeoutMs: Number(process.env.LLM_TIMEOUT_MS || process.env.LLM_REQUEST_TIMEOUT_MS || 30_000),
    logLevel: process.env.LOG_LEVEL || 'info',
  });
});

function initializeDatabase() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      full_name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      cin TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS schedule_sessions (
      id TEXT PRIMARY KEY,
      day_index INTEGER NOT NULL CHECK (day_index BETWEEN 0 AND 5),
      title TEXT NOT NULL,
      room TEXT NOT NULL,
      teacher TEXT NOT NULL,
      color_hex TEXT NOT NULL,
      start_time TEXT NOT NULL,
      end_time TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS tasks (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      title TEXT NOT NULL,
      subject TEXT NOT NULL,
      due_at TEXT NOT NULL,
      completed INTEGER NOT NULL DEFAULT 0,
      reminder_at TEXT,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE INDEX IF NOT EXISTS idx_tasks_user_due
    ON tasks(user_id, due_at);

    CREATE INDEX IF NOT EXISTS idx_schedule_sessions_day_time
    ON schedule_sessions(day_index, start_time);
  `);
}

function validateAuthRequest(body) {
  if (!body || typeof body !== 'object') {
    return { ok: false, error: 'Request body is required' };
  }

  const fullName = typeof body.fullName === 'string' ? body.fullName.trim() : '';
  const email = typeof body.email === 'string' ? body.email.trim() : '';
  const cin = typeof body.cin === 'string' ? body.cin.trim() : '';
  const password = typeof body.password === 'string' ? body.password : '';

  if (!fullName) {
    return { ok: false, error: 'fullName is required' };
  }
  if (!email) {
    return { ok: false, error: 'email is required' };
  }
  if (!cin) {
    return { ok: false, error: 'cin is required' };
  }
  if (!password) {
    return { ok: false, error: 'password is required' };
  }
  if (!/^([A-Za-z][A-Za-z' -]*)$/.test(fullName)) {
    return { ok: false, error: 'fullName contains invalid characters' };
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return { ok: false, error: 'email must be valid' };
  }
  if (!/^[0-9]{8}$/.test(cin)) {
    return { ok: false, error: 'cin must be 8 numbers' };
  }
  if (password.length < 8) {
    return { ok: false, error: 'password minimum 8 characters' };
  }
  if (!/[A-Za-z]/.test(password) || !/[0-9]/.test(password)) {
    return { ok: false, error: 'password must include at least one letter and one number' };
  }

  return {
    ok: true,
    value: {
      fullName,
      email,
      cin,
      password,
    },
  };
}

function validateSignInRequest(body) {
  if (!body || typeof body !== 'object') {
    return { ok: false, error: 'Request body is required' };
  }

  const email = typeof body.email === 'string' ? body.email.trim() : '';
  const password = typeof body.password === 'string' ? body.password : '';

  if (!email) {
    return { ok: false, error: 'email is required' };
  }
  if (!password) {
    return { ok: false, error: 'password is required' };
  }

  return { ok: true, value: { email, password } };
}

function validateProfileUpdateRequest(body) {
  if (!body || typeof body !== 'object') {
    return { ok: false, error: 'Request body is required' };
  }

  const fullName = typeof body.fullName === 'string' ? body.fullName.trim() : '';
  const email = typeof body.email === 'string' ? body.email.trim() : '';

  if (!fullName) {
    return { ok: false, error: 'fullName is required' };
  }
  if (!email) {
    return { ok: false, error: 'email is required' };
  }
  if (!/^([A-Za-z][A-Za-z' -]*)$/.test(fullName)) {
    return { ok: false, error: 'fullName contains invalid characters' };
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return { ok: false, error: 'email must be valid' };
  }

  return {
    ok: true,
    value: {
      fullName,
      email: email.toLowerCase(),
    },
  };
}

function validatePasswordChangeRequest(body) {
  if (!body || typeof body !== 'object') {
    return { ok: false, error: 'Request body is required' };
  }

  const currentPassword =
    typeof body.currentPassword === 'string' ? body.currentPassword : '';
  const newPassword =
    typeof body.newPassword === 'string' ? body.newPassword : '';

  if (!currentPassword) {
    return { ok: false, error: 'currentPassword is required' };
  }
  if (!newPassword) {
    return { ok: false, error: 'newPassword is required' };
  }
  if (newPassword.length < 8) {
    return { ok: false, error: 'password minimum 8 characters' };
  }
  if (!/[A-Za-z]/.test(newPassword) || !/[0-9]/.test(newPassword)) {
    return {
      ok: false,
      error: 'password must include at least one letter and one number',
    };
  }

  return {
    ok: true,
    value: {
      currentPassword,
      newPassword,
    },
  };
}

function hashPassword(password) {
  return crypto.createHash('sha256').update(`studyflow-local:${password}`).digest('hex');
}

function toApiUser(user) {
  return {
    id: user.id,
    fullName: user.fullName,
    email: user.email,
    cin: user.cin,
  };
}

function seedScheduleIfEmpty() {
  const { count } = db.prepare('SELECT COUNT(*) AS count FROM schedule_sessions').get();
  if (count > 0) {
    return;
  }

  const seedPath = path.join(__dirname, '..', 'data', 'schedule.seed.json');
  const seed = JSON.parse(fs.readFileSync(seedPath, 'utf8'));
  const insert = db.prepare(
    `INSERT INTO schedule_sessions
      (id, day_index, title, room, teacher, color_hex, start_time, end_time)
     VALUES
      (@id, @dayIndex, @title, @room, @teacher, @colorHex, @startTime, @endTime)`,
  );

  const transaction = db.transaction((sessions) => {
    for (const session of sessions) {
      const validation = validateSession(session);
      if (!validation.ok) {
        throw new Error(`Invalid seed session ${session.id}: ${validation.error}`);
      }
      insert.run(validation.value);
    }
  });

  transaction(seed);
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

function requireAdminToken(request, response, next) {
  const configuredToken = process.env.ADMIN_TOKEN;
  if (!configuredToken) {
    return response.status(403).json({ error: 'ADMIN_TOKEN is required for writes' });
  }

  const header = request.get('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice('Bearer '.length) : '';
  if (token !== configuredToken) {
    return response.status(401).json({ error: 'Invalid admin token' });
  }

  return next();
}

function validateSession(body) {
  const requiredStrings = ['id', 'title', 'room', 'teacher', 'colorHex', 'startTime', 'endTime'];
  for (const field of requiredStrings) {
    if (typeof body[field] !== 'string' || body[field].trim().length === 0) {
      return { ok: false, error: `${field} is required` };
    }
  }

  if (!Number.isInteger(body.dayIndex) || body.dayIndex < 0 || body.dayIndex > 5) {
    return { ok: false, error: 'dayIndex must be an integer from 0 to 5' };
  }

  if (!/^#[0-9A-Fa-f]{6}$/.test(body.colorHex)) {
    return { ok: false, error: 'colorHex must be a #RRGGBB color' };
  }

  if (!isValidTime(body.startTime) || !isValidTime(body.endTime)) {
    return { ok: false, error: 'startTime and endTime must use HH:mm format' };
  }

  if (timeToMinutes(body.startTime) >= timeToMinutes(body.endTime)) {
    return { ok: false, error: 'startTime must be before endTime' };
  }

  return {
    ok: true,
    value: {
      id: body.id.trim(),
      dayIndex: body.dayIndex,
      title: body.title.trim(),
      room: body.room.trim(),
      teacher: body.teacher.trim(),
      colorHex: body.colorHex.toUpperCase(),
      startTime: body.startTime,
      endTime: body.endTime,
    },
  };
}

function isValidTime(value) {
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(value);
}

function timeToMinutes(value) {
  const [hours, minutes] = value.split(':').map(Number);
  return hours * 60 + minutes;
}

function validateAiRequest(body, expectedMode) {
  if (!body || typeof body !== 'object') {
    return { ok: false, error: 'Request body is required' };
  }

  if (typeof body.conversationId !== 'string' || body.conversationId.trim() === '') {
    return { ok: false, error: 'conversationId is required' };
  }

  if (typeof body.userId !== 'string' || body.userId.trim() === '') {
    return { ok: false, error: 'userId is required' };
  }

  if (!['chat', 'agent'].includes(body.mode)) {
    return { ok: false, error: 'mode must be chat or agent' };
  }

  if (body.mode !== expectedMode) {
    return { ok: false, error: `${expectedMode} endpoint requires mode=${expectedMode}` };
  }

  if (!Array.isArray(body.messages) || body.messages.length === 0) {
    return { ok: false, error: 'messages are required' };
  }

  if (body.messages.length > 24) {
    logger.warn('request.messages.truncated', {
      conversationId: body.conversationId,
      original: body.messages.length,
      kept: 24,
    });
  }

  const messages = body.messages.slice(-24).map((message) => {
    if (!message || typeof message !== 'object') {
      return null;
    }
    if (!['system', 'user', 'assistant', 'tool'].includes(message.role)) {
      return null;
    }
    if (typeof message.content !== 'string') {
      return null;
    }
    return {
      role: message.role,
      content: message.content.slice(0, 8000),
      createdAt: typeof message.createdAt === 'string' ? message.createdAt : null,
    };
  });

  if (messages.some((message) => message === null)) {
    return { ok: false, error: 'messages contain invalid items' };
  }

  const toolResults = Array.isArray(body.toolResults)
    ? body.toolResults.slice(0, 8).map((result) => ({
        toolName: typeof result.toolName === 'string' ? result.toolName : 'unknown',
        success: result.success === true,
        summary: typeof result.summary === 'string' ? result.summary.slice(0, 4000) : '',
        data: result.data && typeof result.data === 'object' ? result.data : {},
      }))
    : [];

  if (expectedMode === 'chat' && toolResults.length > 0) {
    return { ok: false, error: 'toolResults are not allowed for chat requests' };
  }

  return {
    ok: true,
    value: {
      requestId: typeof body.requestId === 'string' && body.requestId.trim() !== '' ? body.requestId.trim() : randomUUID(),
      conversationId: body.conversationId.trim(),
      userId: body.userId.trim(),
      mode: body.mode,
      messages,
      toolResults,
    },
  };
}

function buildAiSuccess(mode, request, run) {
  return {
    ok: true,
    requestId: request.requestId,
    mode,
    conversationId: request.conversationId,
    content: run.content,
    actions: run.actions,
    toolResults: run.toolResults,
    done: true,
  };
}

function buildAiFailure(error, request) {
  return {
    ok: false,
    requestId: request.requestId,
    mode: request.mode,
    conversationId: request.conversationId,
    error: buildAiStreamError(error),
    done: true,
  };
}

function buildAiError(message) {
  return {
    ok: false,
    error: {
      code: 'bad_request',
      message,
    },
  };
}

function aiHttpStatus(error) {
  const status = llmStatus(error);
  if (status === 429) {
    return 429;
  }
  if (status === 401 || status === 403) {
    return 502;
  }
  if (status === 500 || status === 502 || status === 503 || status === 504 || isTimeoutError(error)) {
    return 503;
  }
  if (isConfigurationError(error)) {
    return 500;
  }
  return 500;
}

function buildAiStreamError(error) {
  const status = llmStatus(error);
  if (status === 429 || status === 503) {
    return {
      code: 'ai_provider_unavailable',
      message: 'The AI model is temporarily busy. Please retry in a moment.',
      retryable: true,
      status,
    };
  }
  if (status === 500 || status === 502 || status === 504 || isTimeoutError(error)) {
    return {
      code: 'ai_provider_unavailable',
      message: 'The AI provider is temporarily unavailable. Please retry in a moment.',
      retryable: true,
      ...(status ? { status } : {}),
    };
  }
  if (status === 401 || status === 403 || isConfigurationError(error)) {
    return {
      code: 'ai_provider_configuration_error',
      message: 'The AI backend is not configured correctly. Check the server LLM settings.',
      retryable: false,
      ...(status ? { status } : {}),
    };
  }
  return {
    code: 'ai_stream_failed',
    message: 'The AI request failed. Please try again.',
    retryable: false,
    ...(status ? { status } : {}),
  };
}

function llmStatus(error) {
  if (Number.isInteger(error?.status)) {
    return error.status;
  }
  const match = error?.message?.match(/LLM provider failed with (\d+)/);
  return match ? Number(match[1]) : null;
}

function isTimeoutError(error) {
  return error?.name === 'AbortError' || error?.message?.includes('timed out');
}

function isConfigurationError(error) {
  const message = error?.message || '';
  return (
    message.includes('LLM_API_KEY is required') ||
    message.includes('GEMINI_API_KEY or LLM_API_KEY is required') ||
    message.includes('LLM_MODEL is required') ||
    message.includes('Unsupported LLM_PROVIDER')
  );
}

function asyncHandler(handler) {
  return (request, response, next) => {
    Promise.resolve(handler(request, response, next)).catch(next);
  };
}
