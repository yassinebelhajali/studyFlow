const fs = require('node:fs');
const { randomUUID } = require('node:crypto');
const path = require('node:path');

const cors = require('cors');
const express = require('express');

const { AgentController, writeSse } = require('./ai/agentController');
const { LlmReasoningLayer } = require('./ai/llmReasoningLayer');
const { AgentMemoryStore } = require('./ai/memoryStore');
const { ToolRegistry } = require('./ai/toolRegistry');
const { createScheduleTools } = require('./ai/tools/scheduleTools');
const { createStudyPlanningTools } = require('./ai/tools/studyPlanningTools');
const { loadEnvFiles } = require('./config/env');
const { SupabaseStore } = require('./data/supabaseStore');
const logger = require('./logger');

loadEnvFiles();

const app = express();
const port = Number(process.env.PORT || 3000);
const corsOrigin = process.env.CORS_ORIGIN || '*';
const store = new SupabaseStore({
  supabaseUrl:
    process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || '',
  serviceRoleKey:
    process.env.SUPABASE_SERVICE_ROLE_KEY ||
    process.env.SUPABASE_SECRET_KEY ||
    '',
  publishableKey:
    process.env.SUPABASE_PUBLISHABLE_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ||
    process.env.SUPABASE_ANON_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
    '',
});
const agentMemoryStore = new AgentMemoryStore(store);
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

agentMemoryStore.initialize();
agentController = new AgentController({
  llm: new LlmReasoningLayer(process.env),
  tools: new ToolRegistry([
    ...createScheduleTools(store),
    ...createStudyPlanningTools(store),
  ]),
  memoryStore: agentMemoryStore,
});

app.get('/health', (_request, response) => {
  response.json({ ok: true });
});

app.post('/api/auth/signup', asyncHandler(async (request, response) => {
  const validation = validateAuthRequest(request.body);
  if (!validation.ok) {
    return response.status(400).json({ error: validation.error });
  }

  const { fullName, email, cin, password } = validation.value;
  if (await store.hasUserWithEmail(email)) {
    return response
      .status(409)
      .json({ error: 'An account already exists for this email' });
  }

  const user = await store.signUp({ fullName, email, cin, password });
  return response.status(201).json(toApiUser(user));
}));

app.post('/api/auth/signin', asyncHandler(async (request, response) => {
  const validation = validateSignInRequest(request.body);
  if (!validation.ok) {
    return response.status(400).json({ error: validation.error });
  }

  const user = await store.signIn(validation.value);
  return response.json(toApiUser(user));
}));

app.get('/api/auth/users/:id', asyncHandler(async (request, response) => {
  const userId = String(request.params.id || '').trim();
  if (!userId) {
    return response.status(400).json({ error: 'User id is required' });
  }

  const user = await store.getUserById(userId);

  if (!user) {
    return response.status(404).json({ error: 'User not found' });
  }

  return response.json(user);
}));

app.patch('/api/auth/users/:id', asyncHandler(async (request, response) => {
  const userId = String(request.params.id || '').trim();
  if (!userId) {
    return response.status(400).json({ error: 'User id is required' });
  }

  const validation = validateProfileUpdateRequest(request.body);
  if (!validation.ok) {
    return response.status(400).json({ error: validation.error });
  }

  const existingUser = await store.getUserById(userId);
  if (!existingUser) {
    return response.status(404).json({ error: 'User not found' });
  }

  if (await store.hasUserWithEmail(validation.value.email, userId)) {
    return response
      .status(409)
      .json({ error: 'An account already exists for this email' });
  }

  const updatedUser = await store.updateUserProfile({
    userId,
    fullName: validation.value.fullName,
    email: validation.value.email,
  });

  return response.json(updatedUser);
}));

app.patch('/api/auth/users/:id/password', asyncHandler(async (request, response) => {
  const userId = String(request.params.id || '').trim();
  if (!userId) {
    return response.status(400).json({ error: 'User id is required' });
  }

  const validation = validatePasswordChangeRequest(request.body);
  if (!validation.ok) {
    return response.status(400).json({ error: validation.error });
  }

  const existingUser = await store.getUserById(userId);
  if (!existingUser) {
    return response.status(404).json({ error: 'User not found' });
  }

  await store.changePassword({
    userId,
    currentPassword: validation.value.currentPassword,
    newPassword: validation.value.newPassword,
  });
  return response.status(204).send();
}));

app.get('/api/schedule', asyncHandler(async (_request, response) => {
  const rows = await store.listWeeklySchedule();
  response.json(rows.map(toApiSession));
}));

app.get('/api/courses', asyncHandler(async (_request, response) => {
  const rows = await store.listCourses();
  response.json(rows);
}));

app.post('/api/schedule', requireAdminToken, asyncHandler(async (request, response) => {
  const validation = validateSession(request.body);
  if (!validation.ok) {
    return response.status(400).json({ error: validation.error });
  }

  const session = validation.value;
  await store.upsertScheduleSession(session);
  return response.status(201).json(session);
}));

app.get('/api/tasks', asyncHandler(async (request, response) => {
  const userId = request.query.userId;
  if (!userId) return response.status(400).json({ error: 'userId is required' });

  const rows = await store.listTasksByUser(String(userId));

  response.json(rows.map(toApiTask));
}));

app.post('/api/tasks', asyncHandler(async (request, response) => {
  const { id, userId, title, subject, dueAt, completed, reminderAt, priority } = request.body;
  if (!userId || !title || !dueAt) {
    return response.status(400).json({ error: 'userId, title, and dueAt are required' });
  }

  const taskId = id || randomUUID();
  await store.upsertTask({
    id: taskId,
    userId,
    title,
    subject: subject || 'General',
    dueAt,
    completed: completed === true,
    reminderAt: reminderAt || null,
    priority: typeof priority === 'string' ? priority : 'medium',
  });

  response.status(201).json({ id: taskId, success: true });
}));

app.delete('/api/tasks/:id', asyncHandler(async (request, response) => {
  await store.deleteTask(String(request.params.id || ''));
  response.status(204).send();
}));

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
  const status = Number.isInteger(error?.status) ? error.status : 500;
  response.status(status).json({ error: error.message || 'Internal server error' });
});

startServer();

async function startServer() {
  try {
    await seedScheduleIfEmpty();
    const activePort = await listenWithRetry(port);
    logger.info('server.started', {
      port: activePort,
      env: process.env.NODE_ENV || 'development',
      llmProvider: process.env.LLM_PROVIDER || 'mock',
      llmModel: process.env.GEMINI_MODEL || process.env.LLM_MODEL || '(none)',
      llmTimeoutMs: Number(process.env.LLM_TIMEOUT_MS || process.env.LLM_REQUEST_TIMEOUT_MS || 30_000),
      logLevel: process.env.LOG_LEVEL || 'info',
    });
  } catch (error) {
    logger.error('server.bootstrap.failed', {
      error: error.message,
      stack: error.stack,
    });

    // node --watch can crash on Windows when exiting immediately from bootstrap.
    // Keep process alive so watch mode can recover on file or env changes.
    const isWatchMode = process.execArgv.includes('--watch');
    if (isWatchMode) {
      logger.warn('server.bootstrap.watch_mode_waiting_for_changes');
      process.exitCode = 1;
      return;
    }

    process.exit(1);
  }
}

async function listenWithRetry(initialPort) {
  const env = process.env.NODE_ENV || 'development';
  const maxRetries = env === 'development' ? 10 : 0;
  let activePort = initialPort;
  let attempts = 0;

  while (true) {
    try {
      await listenOnce(activePort);
      return activePort;
    } catch (error) {
      if (error?.code === 'EADDRINUSE' && attempts < maxRetries) {
        logger.warn('server.port_in_use_retrying', {
          attemptedPort: activePort,
          nextPort: activePort + 1,
        });
        activePort += 1;
        attempts += 1;
        continue;
      }
      throw error;
    }
  }
}

function listenOnce(targetPort) {
  return new Promise((resolve, reject) => {
    const server = app.listen(targetPort);
    server.once('listening', resolve);
    server.once('error', (error) => {
      server.removeAllListeners('listening');
      reject(error);
    });
  });
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

function toApiUser(user) {
  return {
    id: user.id,
    fullName: user.fullName,
    email: user.email,
    cin: user.cin,
  };
}

async function seedScheduleIfEmpty() {
  const seedPath = path.join(__dirname, '..', 'data', 'schedule.seed.json');
  const seed = JSON.parse(fs.readFileSync(seedPath, 'utf8'));
  const sessions = [];
  for (const session of seed) {
    const validation = validateSession(session);
    if (!validation.ok) {
      throw new Error(`Invalid seed session ${session.id}: ${validation.error}`);
    }
    sessions.push(validation.value);
  }

  await store.seedScheduleIfEmpty(sessions);
}

function toApiSession(row) {
  return {
    id: row.id,
    dayIndex: row.dayIndex,
    title: row.title,
    room: row.room,
    teacher: row.teacher,
    colorHex: row.colorHex,
    startTime: row.startTime,
    endTime: row.endTime,
  };
}

function toApiTask(row) {
  return {
    id: row.id,
    title: row.title,
    subject: row.subject,
    dueAt: row.dueAt,
    completed: row.completed === true,
    priority: row.priority || 'medium',
    reminderAt: row.reminderAt,
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
