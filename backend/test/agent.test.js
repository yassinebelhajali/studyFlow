const assert = require('node:assert/strict');
const test = require('node:test');

const Database = require('better-sqlite3');

const { AgentController } = require('../src/ai/agentController');
const {
  LlmReasoningLayer,
  buildPlannerMessages,
  extractGeminiText,
  parseGeminiStreamLine,
  toGeminiRequestBody,
} = require('../src/ai/llmReasoningLayer');
const { AgentMemoryStore } = require('../src/ai/memoryStore');
const { ToolRegistry } = require('../src/ai/toolRegistry');
const { createScheduleTools } = require('../src/ai/tools/scheduleTools');
const { createStudyPlanningTools } = require('../src/ai/tools/studyPlanningTools');
const {
  buildConversationContext,
  applyContextBudget,
  buildMemorySummary,
} = require('../src/ai/resultFormatter');

// ---------------------------------------------------------------------------
// Existing behavioural tests
// ---------------------------------------------------------------------------

test('agent plans and executes registered schedule tools', async () => {
  const db = createTestDatabase();
  seedSession(db, {
    id: 'monday-ai',
    dayIndex: 0,
    title: 'AI',
    room: 'Lab 1',
    teacher: 'Dr. Ada',
    colorHex: '#2563EB',
    startTime: '08:30',
    endTime: '10:00',
  });
  const controller = createController(db);

  const run = await controller.complete(
    createRequest('What is my Monday schedule?'),
  );

  assert.equal(run.actions.length, 1);
  assert.equal(run.actions[0].toolName, 'get_today_schedule');
  assert.equal(run.actions[0].status, 'succeeded');
  assert.equal(run.toolResults[0].success, true);
  assert.match(run.toolResults[0].summary, /AI in Lab 1/);
  assert.match(run.content, /get_today_schedule/);
});

test('agent rejects hallucinated tool calls without throwing', async () => {
  const db = createTestDatabase();
  const memoryStore = new AgentMemoryStore(db);
  memoryStore.initialize();
  const controller = new AgentController({
    llm: {
      async plan() {
        return {
          mode: 'tool',
          toolCalls: [{ toolName: 'delete_everything', input: {} }],
        };
      },
      async complete() {
        return 'I could not run that action, so I answered safely.';
      },
    },
    tools: new ToolRegistry(createStudyPlanningTools()),
    memoryStore,
  });

  const run = await controller.complete(createRequest('Delete all my data'));

  assert.equal(run.actions.length, 1);
  assert.equal(run.actions[0].status, 'failed');
  assert.match(run.actions[0].errorMessage, /Unknown tool/);
  assert.equal(run.toolResults[0].success, false);
});

test('agent can stream action events before text deltas', async () => {
  const db = createTestDatabase();
  seedSession(db, {
    id: 'monday-ai',
    dayIndex: 0,
    title: 'AI',
    room: 'Lab 1',
    teacher: 'Dr. Ada',
    colorHex: '#2563EB',
    startTime: '08:30',
    endTime: '10:00',
  });
  const controller = createController(db);
  const writes = [];
  const response = {
    write(payload) {
      writes.push(payload);
    },
  };

  await controller.stream(createRequest('Plan my Monday schedule'), response);

  assert.ok(writes.some((item) => item.includes('"actions"')));
  assert.ok(writes.some((item) => item.includes('"delta"')));
});

// ---------------------------------------------------------------------------
// Memory persistence: assistant response is saved in lastMessages
// ---------------------------------------------------------------------------

test('_saveMemory includes the assistant final answer in lastMessages', async () => {
  const db = createTestDatabase();
  const memoryStore = new AgentMemoryStore(db);
  memoryStore.initialize();

  const assistantReply = 'Here is your study plan for today.';
  const controller = new AgentController({
    llm: {
      async plan() {
        return { mode: 'answer', answer: assistantReply, toolCalls: [] };
      },
      async complete() {
        return assistantReply;
      },
    },
    tools: new ToolRegistry([]),
    memoryStore,
  });

  const req = createRequest('Build me a study plan');
  await controller.complete(req);

  const saved = memoryStore.load(req.conversationId, req.userId);
  const assistantMessages = saved.lastMessages.filter((m) => m.role === 'assistant');
  assert.ok(
    assistantMessages.length > 0,
    'Expected at least one assistant message saved in lastMessages',
  );
  assert.equal(assistantMessages[assistantMessages.length - 1].content, assistantReply);
});

test('agent retries transient planner failures before running tools or answering', async () => {
  const db = createTestDatabase();
  const memoryStore = new AgentMemoryStore(db);
  memoryStore.initialize();
  let planAttempts = 0;

  const controller = new AgentController({
    llm: {
      async plan() {
        planAttempts += 1;
        if (planAttempts < 3) {
          throw new Error('LLM provider failed with 503: temporary overload');
        }
        return { mode: 'answer', answer: 'Direct answer.', toolCalls: [] };
      },
      async complete() {
        return 'Recovered after planner retry.';
      },
    },
    tools: new ToolRegistry([]),
    memoryStore,
  });

  const run = await controller.complete(createRequest('Plan my day'));

  assert.equal(planAttempts, 3);
  assert.equal(run.content, 'Recovered after planner retry.');
});

test('planner prompt includes recent conversation context for follow-up requests', () => {
  const aiRequest = {
    conversationId: 'conversation_followup',
    userId: 'user_followup',
    mode: 'agent',
    messages: [
      { role: 'user', content: 'What is my Monday schedule?', createdAt: null },
      { role: 'assistant', content: 'You have AI in Lab 1 at 08:30.', createdAt: null },
      { role: 'user', content: 'Plan around that class.', createdAt: null },
    ],
    toolResults: [],
  };

  const messages = buildPlannerMessages({
    aiRequest,
    memory: { summary: '', lastMessages: [] },
    tools: [{ name: 'build_study_plan', description: 'Builds a plan', inputSchema: {} }],
  });

  const promptText = messages.map((message) => message.content).join('\n');
  assert.match(promptText, /Recent conversation context/);
  assert.match(promptText, /What is my Monday schedule/);
  assert.match(promptText, /You have AI in Lab 1/);
  assert.match(promptText, /Plan around that class/);
});

test('agent returns capability fallback when LLM is busy', async () => {
  const db = createTestDatabase();
  const memoryStore = new AgentMemoryStore(db);
  memoryStore.initialize();
  const controller = new AgentController({
    llm: {
      async plan() {
        throw new Error('The AI model is temporarily busy.');
      },
      async complete() {
        throw new Error('Should not call complete in this fallback path');
      },
    },
    tools: new ToolRegistry([]),
    memoryStore,
  });

  const run = await controller.complete(createRequest('the agent what it can do ?'));

  assert.equal(run.degraded, true);
  assert.match(run.content, /local StudyFlow fallback/);
  assert.match(run.content, /In Agent mode I can help/);
  assert.match(run.content, /weekly timetable/);
});

test('agent fallback runs local tools when planner LLM is unavailable', async () => {
  const db = createTestDatabase();
  seedSession(db, {
    id: 'monday-ai',
    dayIndex: 0,
    title: 'AI',
    room: 'Lab 1',
    teacher: 'Dr. Ada',
    colorHex: '#2563EB',
    startTime: '08:30',
    endTime: '10:00',
  });
  const memoryStore = new AgentMemoryStore(db);
  memoryStore.initialize();
  const controller = new AgentController({
    llm: {
      async plan() {
        throw new Error('The AI model is temporarily busy.');
      },
      async complete() {
        throw new Error('Should not call complete in this fallback path');
      },
    },
    tools: new ToolRegistry([
      ...createScheduleTools(db),
      ...createStudyPlanningTools(),
    ]),
    memoryStore,
  });

  const run = await controller.complete(
    createRequest('Plan my Monday schedule for 90 minutes'),
  );

  assert.equal(run.degraded, true);
  assert.equal(run.actions.length, 2);
  assert.deepEqual(
    run.actions.map((action) => action.toolName),
    ['get_today_schedule', 'build_study_plan'],
  );
  assert.match(run.content, /I still checked the available StudyFlow data/);
  assert.match(run.content, /AI in Lab 1/);
  assert.match(run.content, /Study plan/);
});

// ---------------------------------------------------------------------------
// Context injection: thin client context is enriched from memory.lastMessages
// ---------------------------------------------------------------------------

test('buildConversationContext injects stored messages when client sends only 1 user turn', () => {
  const memory = {
    summary: '',
    lastMessages: [
      { role: 'user', content: 'What is my Monday schedule?' },
      { role: 'assistant', content: 'You have AI in Lab 1 from 08:30.' },
    ],
  };

  const aiRequest = {
    messages: [{ role: 'user', content: 'Thanks, and what about Tuesday?', createdAt: null }],
  };

  const context = buildConversationContext(aiRequest, memory);
  const roles = context.map((m) => m.role);
  // Should contain the stored user/assistant pair + the new user message
  assert.ok(context.length >= 3, `Expected ≥ 3 messages, got ${context.length}`);
  assert.equal(context[context.length - 1].content, 'Thanks, and what about Tuesday?');
  assert.ok(roles.includes('assistant'), 'Expected stored assistant message to be injected');
});

test('buildConversationContext does not inject memory when client sends enough history', () => {
  const memory = {
    summary: '',
    lastMessages: [
      { role: 'user', content: 'Old message from memory' },
      { role: 'assistant', content: 'Old reply from memory' },
    ],
  };

  // 3 user turns = MIN_CLIENT_USER_TURNS_FOR_FULL_TRUST
  const aiRequest = {
    messages: [
      { role: 'user', content: 'Turn 1', createdAt: null },
      { role: 'assistant', content: 'Reply 1', createdAt: null },
      { role: 'user', content: 'Turn 2', createdAt: null },
      { role: 'assistant', content: 'Reply 2', createdAt: null },
      { role: 'user', content: 'Turn 3', createdAt: null },
    ],
  };

  const context = buildConversationContext(aiRequest, memory);
  const contents = context.map((m) => m.content);
  assert.ok(
    !contents.includes('Old message from memory'),
    'Should not inject stored messages when client history is sufficient',
  );
});

test('buildConversationContext deduplicates when stored context ends with the same user message the client sends', () => {
  // Simulate: a prior request was saved in memory but the assistant never replied
  // (e.g. network drop).  The client retries the same message.
  const lastUserMsg = 'What is my schedule?';
  const memory = {
    summary: '',
    // Stored ends with the user message — no assistant reply yet
    lastMessages: [{ role: 'user', content: lastUserMsg }],
  };

  const aiRequest = {
    messages: [{ role: 'user', content: lastUserMsg, createdAt: null }],
  };

  const context = buildConversationContext(aiRequest, memory);
  const userMessages = context.filter((m) => m.role === 'user' && m.content === lastUserMsg);
  assert.equal(
    userMessages.length,
    1,
    'Consecutive duplicate user messages at the stored/client boundary should be collapsed to one',
  );
});

// ---------------------------------------------------------------------------
// Context budget: oversized messages are trimmed
// ---------------------------------------------------------------------------

test('applyContextBudget keeps the most recent message regardless of size', () => {
  const huge = 'x'.repeat(25_000); // exceeds 20 000 char budget alone
  const messages = [
    { role: 'user', content: 'old message' },
    { role: 'assistant', content: huge },
  ];

  const result = applyContextBudget(messages);
  assert.ok(result.length >= 1, 'Expected at least the most recent message');
  assert.equal(result[result.length - 1].content, huge, 'Most recent message must survive budget');
});

test('applyContextBudget drops oldest messages when budget is exceeded', () => {
  const messages = Array.from({ length: 10 }, (_, i) => ({
    role: i % 2 === 0 ? 'user' : 'assistant',
    content: 'a'.repeat(3_000), // 10 × 3 000 = 30 000 chars > 20 000 budget
  }));

  const result = applyContextBudget(messages);
  assert.ok(result.length < messages.length, 'Expected some messages to be dropped');
  assert.deepEqual(
    result[result.length - 1],
    messages[messages.length - 1],
    'Most recent message must be kept',
  );
});

// ---------------------------------------------------------------------------
// Summary structure: buildMemorySummary produces structured lines
// ---------------------------------------------------------------------------

test('buildMemorySummary includes structured sections for each data type', () => {
  const summary = buildMemorySummary({
    previousSummary: 'Previous context here.',
    messages: [
      { role: 'user', content: 'What is my schedule?' },
      { role: 'assistant', content: 'You have AI at 08:30.' },
    ],
    toolResults: [{ success: true, toolName: 'get_today_schedule' }],
    finalAnswer: 'You have AI in Lab 1 today.',
  });

  assert.match(summary, /\[User asked\]/);
  assert.match(summary, /\[Tools used\]/);
  assert.match(summary, /\[Last reply\]/);
  assert.match(summary, /Previous context here/);
});

test('buildMemorySummary stays within 2400 char limit', () => {
  const longPrev = 'p'.repeat(3000);
  const summary = buildMemorySummary({
    previousSummary: longPrev,
    messages: [{ role: 'user', content: 'Short question' }],
    toolResults: [],
    finalAnswer: 'Short answer',
  });

  assert.ok(
    summary.length <= 2400,
    `Summary exceeded 2400 chars: ${summary.length}`,
  );
});

// ---------------------------------------------------------------------------
// Gemini provider adapter
// ---------------------------------------------------------------------------

test('toGeminiRequestBody maps StudyFlow messages to Gemini REST format', () => {
  const body = toGeminiRequestBody({
    temperature: 0.2,
    messages: [
      { role: 'system', content: 'You are StudyFlow.' },
      { role: 'system', content: 'Use concise answers.' },
      { role: 'user', content: 'Hello' },
      { role: 'assistant', content: 'Hi.' },
      { role: 'user', content: 'Plan my day.' },
    ],
  });

  assert.deepEqual(body.system_instruction, {
    parts: [{ text: 'You are StudyFlow.\n\nUse concise answers.' }],
  });
  assert.deepEqual(body.contents, [
    { role: 'user', parts: [{ text: 'Hello' }] },
    { role: 'model', parts: [{ text: 'Hi.' }] },
    { role: 'user', parts: [{ text: 'Plan my day.' }] },
  ]);
  assert.equal(body.generationConfig.temperature, 0.2);
});

test('Gemini helpers extract full text from standard and stream payloads', () => {
  const payload = {
    candidates: [
      {
        content: {
          parts: [{ text: 'Hello' }, { text: ' from Gemini' }],
        },
      },
    ],
  };

  assert.equal(extractGeminiText(payload), 'Hello from Gemini');
  assert.equal(parseGeminiStreamLine(`data: ${JSON.stringify(payload)}`), 'Hello from Gemini');
});

test('gemini provider calls generateContent with API key header', async () => {
  const originalFetch = globalThis.fetch;
  let captured;

  globalThis.fetch = async (url, options) => {
    captured = { url: String(url), options };
    return new Response(
      JSON.stringify({
        candidates: [
          {
            content: {
              parts: [{ text: 'Gemini is connected.' }],
            },
          },
        ],
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      },
    );
  };

  try {
    const llm = new LlmReasoningLayer({
      LLM_PROVIDER: 'gemini',
      LLM_MODEL: 'gemini-test',
      GEMINI_API_KEY: 'test-key',
      LLM_TIMEOUT_MS: '5000',
    });

    const content = await llm.complete({
      messages: [{ role: 'user', content: 'Ping' }],
      temperature: 0,
    });

    assert.equal(content, 'Gemini is connected.');
    assert.match(captured.url, /\/v1beta\/models\/gemini-test:generateContent$/);
    assert.equal(captured.options.headers['x-goog-api-key'], 'test-key');
  } finally {
    globalThis.fetch = originalFetch;
  }
});

// ---------------------------------------------------------------------------
// Memory round-trip: full conversation persists context across two requests
// ---------------------------------------------------------------------------

test('context is available on the second request via memory after first completes', async () => {
  const db = createTestDatabase();
  const memoryStore = new AgentMemoryStore(db);
  memoryStore.initialize();

  const capturedMessages = [];
  const controller = new AgentController({
    llm: {
      async plan() {
        return { mode: 'answer', answer: 'Direct answer.', toolCalls: [] };
      },
      async complete({ messages }) {
        capturedMessages.push(...messages);
        return 'Response from turn.';
      },
    },
    tools: new ToolRegistry([]),
    memoryStore,
  });

  const convId = 'conv_roundtrip';
  const userId = 'user_roundtrip';

  // First request — single user message
  await controller.complete({
    conversationId: convId,
    userId,
    mode: 'agent',
    messages: [{ role: 'user', content: 'Remember: my name is Alex.', createdAt: new Date().toISOString() }],
    toolResults: [],
  });

  capturedMessages.length = 0;

  // Second request — sends only a new message (simulates new device / cleared history)
  await controller.complete({
    conversationId: convId,
    userId,
    mode: 'agent',
    messages: [{ role: 'user', content: 'What is my name?', createdAt: new Date().toISOString() }],
    toolResults: [],
  });

  const allContent = capturedMessages.map((m) => m.content).join('\n');
  assert.ok(
    allContent.includes('Remember: my name is Alex.') ||
    allContent.includes('my name is Alex') ||
    allContent.includes('[User asked]'),
    'Second request should have access to context from the first request via memory injection',
  );
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createController(db) {
  const memoryStore = new AgentMemoryStore(db);
  memoryStore.initialize();
  return new AgentController({
    llm: new LlmReasoningLayer({ LLM_PROVIDER: 'mock' }),
    tools: new ToolRegistry([
      ...createScheduleTools(db),
      ...createStudyPlanningTools(),
    ]),
    memoryStore,
  });
}

function createTestDatabase() {
  const db = new Database(':memory:');
  db.exec(`
    CREATE TABLE schedule_sessions (
      id TEXT PRIMARY KEY,
      day_index INTEGER NOT NULL CHECK (day_index BETWEEN 0 AND 5),
      title TEXT NOT NULL,
      room TEXT NOT NULL,
      teacher TEXT NOT NULL,
      color_hex TEXT NOT NULL,
      start_time TEXT NOT NULL,
      end_time TEXT NOT NULL
    );
  `);
  return db;
}

function seedSession(db, session) {
  db.prepare(`
    INSERT INTO schedule_sessions
      (id, day_index, title, room, teacher, color_hex, start_time, end_time)
    VALUES
      (@id, @dayIndex, @title, @room, @teacher, @colorHex, @startTime, @endTime)
  `).run(session);
}

function createRequest(content) {
  return {
    conversationId: 'conversation_test',
    userId: 'user_test',
    mode: 'agent',
    messages: [
      {
        role: 'user',
        content,
        createdAt: new Date().toISOString(),
      },
    ],
    toolResults: [],
  };
}
