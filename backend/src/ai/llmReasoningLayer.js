const logger = require('../logger');
const { buildConversationContext } = require('./resultFormatter');

class LlmReasoningLayer {
  constructor(env = process.env) {
    this._env = env;
  }

  async plan({ aiRequest, memory, tools }) {
    const provider = this._provider();
    if (provider === 'mock') {
      return mockPlan(aiRequest);
    }

    const messages = buildPlannerMessages({ aiRequest, memory, tools });
    const elapsed = logger.startTimer();
    logger.debug('llm.plan.start', {
      conversationId: aiRequest.conversationId,
      provider,
      model: this._modelName(provider),
      messageCount: messages.length,
    });

    let raw;
    try {
      raw = await this.complete({ messages, temperature: 0 });
    } catch (error) {
      logger.error('llm.plan.failed', {
        conversationId: aiRequest.conversationId,
        durationMs: elapsed(),
        error: error.message,
      });
      throw error;
    }

    const plan = parsePlannerOutput(raw);

    if (plan.invalidReason) {
      logger.warn('llm.plan.invalid_json', {
        conversationId: aiRequest.conversationId,
        durationMs: elapsed(),
        invalidReason: plan.invalidReason,
        rawSnippet: raw.slice(0, 200),
      });
    } else {
      logger.debug('llm.plan.done', {
        conversationId: aiRequest.conversationId,
        durationMs: elapsed(),
        planMode: plan.mode,
        toolCallCount: plan.toolCalls?.length ?? 0,
      });
    }

    return plan;
  }

  async complete({ messages, temperature }) {
    const provider = this._provider();
    if (provider === 'mock') {
      return mockCompletion(messages);
    }
    if (provider === 'openai-compatible') {
      const elapsed = logger.startTimer();
      logger.debug('llm.complete.start', {
        provider,
        model: this._modelName(provider),
        messageCount: messages.length,
      });

      const llmResponse = await this._callOpenAiCompatible({ messages, stream: false, temperature });
      let decoded;
      try {
        decoded = await llmResponse.json();
      } catch (error) {
        logger.error('llm.complete.invalid_json', { durationMs: elapsed(), error: error.message });
        throw new Error('LLM provider returned non-JSON response');
      }

      const content =
        decoded &&
        decoded.choices &&
        decoded.choices[0] &&
        decoded.choices[0].message &&
        decoded.choices[0].message.content;

      if (typeof content !== 'string') {
        logger.error('llm.complete.missing_content', {
          durationMs: elapsed(),
          responseKeys: decoded ? Object.keys(decoded) : [],
        });
        throw new Error('LLM provider returned an invalid completion');
      }

      logger.debug('llm.complete.done', { durationMs: elapsed(), contentLength: content.length });
      return content;
    }

    if (provider === 'gemini') {
      const elapsed = logger.startTimer();
      logger.debug('llm.complete.start', {
        provider,
        model: this._modelName(provider),
        messageCount: messages.length,
      });

      const llmResponse = await this._callGemini({ messages, stream: false, temperature });
      let decoded;
      try {
        decoded = await llmResponse.json();
      } catch (error) {
        logger.error('llm.complete.invalid_json', { durationMs: elapsed(), error: error.message });
        throw new Error('LLM provider returned non-JSON response');
      }

      const content = extractGeminiText(decoded);
      if (typeof content !== 'string' || content.length === 0) {
        logger.error('llm.complete.missing_content', {
          durationMs: elapsed(),
          responseKeys: decoded ? Object.keys(decoded) : [],
          finishReason: decoded?.candidates?.[0]?.finishReason,
          blockReason: decoded?.promptFeedback?.blockReason,
        });
        throw new Error('LLM provider returned an invalid completion');
      }

      logger.debug('llm.complete.done', { durationMs: elapsed(), contentLength: content.length });
      return content;
    }

    throw new Error(`Unsupported LLM_PROVIDER "${provider}"`);
  }

  async stream({ messages, onDelta, temperature }) {
    const provider = this._provider();
    if (provider === 'mock') {
      const content = mockCompletion(messages);
      for (const word of content.split(' ')) {
        await delay(18);
        onDelta(`${word} `);
      }
      return content;
    }

    const elapsed = logger.startTimer();
    logger.debug('llm.stream.start', {
      provider,
      model: this._modelName(provider),
      messageCount: messages.length,
    });

    let llmResponse;
    let parseLine;
    if (provider === 'openai-compatible') {
      llmResponse = await this._callOpenAiCompatible({ messages, stream: true, temperature });
      parseLine = parseOpenAiCompatibleStreamLine;
    } else if (provider === 'gemini') {
      llmResponse = await this._callGemini({ messages, stream: true, temperature });
      parseLine = parseGeminiStreamLine;
    } else {
      throw new Error(`Unsupported LLM_PROVIDER "${provider}"`);
    }

    const decoder = new TextDecoder();
    const reader = llmResponse.body.getReader();
    let buffer = '';
    let fullText = '';
    let deltaCount = 0;

    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }

      buffer += decoder.decode(value, { stream: true });
      while (buffer.includes('\n')) {
        const lineEnd = buffer.indexOf('\n');
        const line = buffer.slice(0, lineEnd).trim();
        buffer = buffer.slice(lineEnd + 1);
        const delta = parseLine(line);
        if (delta === '[DONE]') {
          logger.debug('llm.stream.done', { durationMs: elapsed(), deltaCount, fullLength: fullText.length });
          return fullText;
        }
        if (delta) {
          fullText += delta;
          deltaCount++;
          onDelta(delta);
        }
      }
    }

    const tail = parseLine(buffer.trim());
    if (tail && tail !== '[DONE]') {
      fullText += tail;
      onDelta(tail);
    }

    logger.debug('llm.stream.done', { durationMs: elapsed(), deltaCount, fullLength: fullText.length });
    return fullText;
  }

  async _callOpenAiCompatible({ messages, stream, temperature }) {
    if (typeof fetch !== 'function') {
      throw new Error('This Node.js runtime does not provide fetch');
    }

    const apiKey = this._env.LLM_API_KEY;
    if (!apiKey) {
      throw new Error('LLM_API_KEY is required when LLM_PROVIDER=openai-compatible');
    }

    const baseUrl = (this._env.LLM_BASE_URL || 'https://api.openai.com/v1').replace(/\/$/, '');
    const model = this._modelName('openai-compatible');
    if (!model) {
      throw new Error('LLM_MODEL is required when LLM_PROVIDER=openai-compatible');
    }

    const controller = new AbortController();
    const timeoutMs = this._timeoutMs();
    const timeoutId = setTimeout(() => {
      controller.abort();
    }, timeoutMs);

    let llmResponse;
    try {
      llmResponse = await fetch(`${baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          stream,
          temperature: Number(temperature ?? this._env.LLM_TEMPERATURE ?? 0.3),
          messages,
        }),
        signal: controller.signal,
      });
    } catch (error) {
      clearTimeout(timeoutId);
      if (error.name === 'AbortError') {
        throw new Error(`LLM request timed out after ${timeoutMs}ms`);
      }
      throw error;
    }
    clearTimeout(timeoutId);

    if (!llmResponse.ok) {
      const detail = await llmResponse.text().catch(() => '(unreadable body)');
      throw new Error(`LLM provider failed with ${llmResponse.status}: ${detail}`);
    }

    return llmResponse;
  }

  async _callGemini({ messages, stream, temperature }) {
    if (typeof fetch !== 'function') {
      throw new Error('This Node.js runtime does not provide fetch');
    }

    const apiKey = this._env.GEMINI_API_KEY || this._env.LLM_API_KEY;
    if (!apiKey) {
      throw new Error('GEMINI_API_KEY or LLM_API_KEY is required when LLM_PROVIDER=gemini');
    }

    const model = this._modelName('gemini');
    const baseUrl = (this._env.GEMINI_BASE_URL || 'https://generativelanguage.googleapis.com/v1beta').replace(/\/$/, '');
    const method = stream ? 'streamGenerateContent' : 'generateContent';
    const url = `${baseUrl}/${toGeminiModelPath(model)}:${method}${stream ? '?alt=sse' : ''}`;
    const controller = new AbortController();
    const timeoutMs = this._timeoutMs();
    const timeoutId = setTimeout(() => {
      controller.abort();
    }, timeoutMs);

    let llmResponse;
    try {
      llmResponse = await fetch(url, {
        method: 'POST',
        headers: {
          'x-goog-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(toGeminiRequestBody({
          messages,
          temperature: Number(temperature ?? this._env.LLM_TEMPERATURE ?? 0.3),
        })),
        signal: controller.signal,
      });
    } catch (error) {
      clearTimeout(timeoutId);
      if (error.name === 'AbortError') {
        throw new Error(`LLM request timed out after ${timeoutMs}ms`);
      }
      throw error;
    }
    clearTimeout(timeoutId);

    if (!llmResponse.ok) {
      const detail = await llmResponse.text().catch(() => '(unreadable body)');
      throw new Error(`LLM provider failed with ${llmResponse.status}: ${detail}`);
    }

    return llmResponse;
  }

  _provider() {
    return (this._env.LLM_PROVIDER || 'mock').toLowerCase();
  }

  _modelName(provider = this._provider()) {
    if (provider === 'gemini') {
      return this._env.GEMINI_MODEL || this._env.LLM_MODEL || 'gemini-3-flash-preview';
    }
    return this._env.LLM_MODEL;
  }

  _timeoutMs() {
    return Number(this._env.LLM_TIMEOUT_MS || this._env.LLM_REQUEST_TIMEOUT_MS || 30_000);
  }
}

function buildPlannerMessages({ aiRequest, memory, tools }) {
  const latestUser = lastUserMessage(aiRequest);
  const recentContext = buildConversationContext(aiRequest, memory)
    .slice(-8)
    .map((message) => `${message.role}: ${message.content}`)
    .join('\n');

  return [
    {
      role: 'system',
      content: [
        'You are the planning layer for StudyFlow Agent.',
        'StudyFlow helps students with schedules, study plans, revision, homework breakdowns, and course questions.',
        'Decide whether the request should be answered directly or needs one or more registered tools.',
        'Use tools for schedule facts or deterministic planning context when a matching tool exists.',
        'Answer directly for explanations, summaries, quiz generation, general advice, or questions that do not require app data.',
        'You must return only JSON with this shape:',
        '{"mode":"answer","answer":"brief intent and response guidance"}',
        'or {"mode":"tool","toolCalls":[{"toolName":"exact_registered_tool_name","input":{}}]}.',
        'Never invent tool names, app actions, or unavailable data. Use at most three tool calls.',
        'If the latest request is a follow-up, use the recent conversation context to resolve references like "that", "tomorrow", or "Tuesday".',
      ].join(' '),
    },
    {
      role: 'system',
      content: `Registered tools:\n${JSON.stringify(tools, null, 2)}`,
    },
    {
      role: 'system',
      content: `Memory summary:\n${memory.summary || 'No stored session memory.'}`,
    },
    {
      role: 'system',
      content: `Recent conversation context:\n${recentContext || 'No recent conversation context.'}`,
    },
    {
      role: 'user',
      content: latestUser ? latestUser.content : '',
    },
  ];
}

function parsePlannerOutput(content) {
  const decoded = parseJsonObject(content);
  if (!decoded) {
    return {
      mode: 'answer',
      answer: 'I can answer directly without using an app action.',
      toolCalls: [],
      invalidReason: 'Planner did not return valid JSON',
    };
  }

  if (decoded.mode === 'tool' && Array.isArray(decoded.toolCalls)) {
    return {
      mode: 'tool',
      answer: '',
      toolCalls: decoded.toolCalls.slice(0, 3).map((call) => ({
        toolName: typeof call.toolName === 'string' ? call.toolName : '',
        input: call.input && typeof call.input === 'object' ? call.input : {},
      })),
    };
  }

  return {
    mode: 'answer',
    answer: typeof decoded.answer === 'string' ? decoded.answer : '',
    toolCalls: [],
  };
}

function parseJsonObject(content) {
  const trimmed = String(content || '').trim();
  const candidates = [
    trimmed,
    trimmed.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, ''),
    trimmed.slice(trimmed.indexOf('{'), trimmed.lastIndexOf('}') + 1),
  ].filter((item) => item.startsWith('{') && item.endsWith('}'));

  for (const candidate of candidates) {
    try {
      const decoded = JSON.parse(candidate);
      if (decoded && typeof decoded === 'object' && !Array.isArray(decoded)) {
        return decoded;
      }
    } catch (_error) {
      // Try next candidate.
    }
  }
  return null;
}

function mockPlan(aiRequest) {
  const latest = lastUserMessage(aiRequest);
  const text = (latest ? latest.content : '').toLowerCase();
  const calls = [];

  if (
    text.includes('whole week') ||
    text.includes('weekly') ||
    text.includes('this week') ||
    text.includes('week schedule')
  ) {
    calls.push({ toolName: 'get_weekly_schedule', input: {} });
  } else if (
    text.includes('schedule') ||
    text.includes('class') ||
    text.includes('course') ||
    text.includes('emploi') ||
    text.includes('room') ||
    text.includes('teacher')
  ) {
    calls.push({
      toolName: 'get_today_schedule',
      input: dayIndexFromText(text),
    });
  }

  if (
    text.includes('plan') ||
    text.includes('study') ||
    text.includes('homework') ||
    text.includes('task') ||
    text.includes('organize') ||
    text.includes('revise')
  ) {
    calls.push({
      toolName: 'build_study_plan',
      input: {
        goal: latest ? latest.content.slice(0, 240) : 'Study session',
        availableMinutes: minutesFromText(text) || 90,
        priority: text.includes('urgent') || text.includes('exam') ? 'high' : 'normal',
      },
    });
  }

  if (calls.length > 0 && aiRequest.mode === 'agent') {
    return { mode: 'tool', answer: '', toolCalls: calls.slice(0, 3) };
  }

  return {
    mode: 'answer',
    answer: 'Answer directly without calling a tool.',
    toolCalls: [],
  };
}

function dayIndexFromText(text) {
  const days = {
    monday: 0,
    tuesday: 1,
    wednesday: 2,
    thursday: 3,
    friday: 4,
    saturday: 5,
  };
  for (const [day, index] of Object.entries(days)) {
    if (text.includes(day)) {
      return { dayIndex: index };
    }
  }
  return {};
}

function minutesFromText(text) {
  const match = text.match(/(\d{1,3})\s*(?:min|minute|minutes)/);
  if (!match) {
    return null;
  }
  return Number(match[1]);
}

function mockCompletion(messages) {
  const latestUser = [...messages].reverse().find((message) => message.role === 'user');
  const toolContext = messages
    .filter((message) => message.role === 'system' && message.content.includes('Trusted tool/action results:'))
    .map((message) => message.content)
    .join('\n');

  if (toolContext) {
    return [
      'I checked the available StudyFlow actions.',
      toolContext
        .replace('Trusted tool/action results:', '')
        .trim()
        .split('\n')
        .map((line) => `- ${line}`)
        .join('\n'),
      'Use this as the source of truth for the next step.',
    ].join('\n');
  }

  return [
    'Mock AI backend active.',
    '',
    `Received: "${latestUser ? latestUser.content : 'No prompt'}".`,
    '',
    'Set LLM_PROVIDER=gemini, GEMINI_API_KEY, and LLM_MODEL to enable real Gemini reasoning.',
  ].join('\n');
}

function parseOpenAiCompatibleStreamLine(line) {
  if (!line || line.startsWith(':')) {
    return null;
  }
  const payload = line.startsWith('data:') ? line.slice('data:'.length).trim() : line;
  if (!payload) {
    return null;
  }
  if (payload === '[DONE]') {
    return '[DONE]';
  }
  try {
    const decoded = JSON.parse(payload);
    return (
      decoded.choices &&
      decoded.choices[0] &&
      decoded.choices[0].delta &&
      decoded.choices[0].delta.content
    );
  } catch (_error) {
    return null;
  }
}

function parseGeminiStreamLine(line) {
  if (!line || line.startsWith(':')) {
    return null;
  }
  const payload = line.startsWith('data:') ? line.slice('data:'.length).trim() : line;
  if (!payload) {
    return null;
  }
  try {
    return extractGeminiText(JSON.parse(payload));
  } catch (_error) {
    return null;
  }
}

function toGeminiRequestBody({ messages, temperature }) {
  const { systemInstruction, contents } = toGeminiContents(messages);
  const body = {
    contents,
    generationConfig: {
      temperature,
    },
  };
  if (systemInstruction) {
    body.system_instruction = {
      parts: [{ text: systemInstruction }],
    };
  }
  return body;
}

function toGeminiContents(messages) {
  const systemParts = [];
  const contents = [];

  for (const message of messages) {
    const text = typeof message.content === 'string' ? message.content.trim() : '';
    if (!text) {
      continue;
    }
    if (message.role === 'system') {
      systemParts.push(text);
      continue;
    }

    const role = message.role === 'assistant' ? 'model' : 'user';
    const previous = contents[contents.length - 1];
    if (previous && previous.role === role) {
      previous.parts.push({ text });
      continue;
    }

    contents.push({
      role,
      parts: [{ text }],
    });
  }

  if (contents.length === 0) {
    contents.push({
      role: 'user',
      parts: [{ text: 'Continue.' }],
    });
  }

  return {
    systemInstruction: systemParts.join('\n\n'),
    contents,
  };
}

function extractGeminiText(decoded) {
  const parts = decoded?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) {
    return '';
  }
  return parts
    .map((part) => (typeof part?.text === 'string' ? part.text : ''))
    .filter(Boolean)
    .join('');
}

function toGeminiModelPath(model) {
  if (model.startsWith('models/') || model.startsWith('tunedModels/')) {
    return model;
  }
  return `models/${model}`;
}

function lastUserMessage(aiRequest) {
  return [...aiRequest.messages].reverse().find((message) => message.role === 'user');
}

function delay(milliseconds) {
  return new Promise((resolve) => {
    setTimeout(resolve, milliseconds);
  });
}

module.exports = {
  LlmReasoningLayer,
  buildPlannerMessages,
  parsePlannerOutput,
  mockPlan,
  parseGeminiStreamLine,
  toGeminiRequestBody,
  extractGeminiText,
};
