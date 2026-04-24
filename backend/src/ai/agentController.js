const {
  buildChatMessages,
  buildFinalAnswerMessages,
  buildMemorySummary,
} = require('./resultFormatter');
const logger = require('../logger');

// HTTP status codes from the LLM provider that are safe to retry
const RETRYABLE_LLM_STATUSES = new Set([429, 500, 502, 503, 504]);
const MAX_RETRIES = 2;
const RETRY_BASE_MS = 400;

class AgentController {
  constructor({ llm, tools, memoryStore, maxToolCalls = 3 }) {
    this._llm = llm;
    this._tools = tools;
    this._memoryStore = memoryStore;
    this._maxToolCalls = maxToolCalls;
  }

  async completeChat(aiRequest) {
    return this._run(aiRequest, {
      onAction: null,
      onDelta: null,
      stream: false,
    });
  }

  async completeAgent(aiRequest) {
    return this._run(aiRequest, {
      onAction: null,
      onDelta: null,
      stream: false,
    });
  }

  async complete(aiRequest) {
    return this._run(aiRequest, {
      onAction: null,
      onDelta: null,
      stream: false,
    });
  }

  async streamChat(aiRequest, response) {
    return this._run(aiRequest, {
      stream: true,
      onAction: (action) => writeSse(response, { event: 'action', actions: [action] }),
      onDelta: (delta) => writeSse(response, { event: 'delta', delta }),
    });
  }

  async streamAgent(aiRequest, response) {
    return this._run(aiRequest, {
      stream: true,
      onAction: (action) => writeSse(response, { event: 'action', actions: [action] }),
      onDelta: (delta) => writeSse(response, { event: 'delta', delta }),
    });
  }

  async stream(aiRequest, response) {
    return this.streamAgent(aiRequest, response);
  }

  async _run(aiRequest, { stream, onAction, onDelta }) {
    const elapsed = logger.startTimer();
    const { conversationId, userId, mode } = aiRequest;

    logger.info('agent.run.start', {
      conversationId,
      userId,
      mode,
      stream,
      messageCount: aiRequest.messages.length,
    });

    const memory = await this._memoryStore.load(conversationId, userId);
    logger.debug('agent.memory.loaded', {
      conversationId,
      hasSummary: memory.summary.length > 0,
      storedMessageCount: memory.lastMessages.length,
    });

    const actions = [];
    const toolResults = [];

    try {
      if (aiRequest.mode === 'chat') {
        const content = await this._respondWithRetry({
          stream,
          onDelta,
          messages: buildChatMessages({ aiRequest, memory }),
          conversationId,
        });
        await this._saveMemory({ aiRequest, memory, toolResults, finalAnswer: content });
        logger.info('agent.run.done', { conversationId, mode, durationMs: elapsed(), contentLength: content.length });
        return { content, actions, toolResults };
      }

      const providedToolResults = Array.isArray(aiRequest.toolResults)
        ? aiRequest.toolResults.filter((result) => result && typeof result.summary === 'string')
        : [];

      if (providedToolResults.length > 0) {
        logger.debug('agent.provided_tool_results', { conversationId, count: providedToolResults.length });
        const messages = buildFinalAnswerMessages({
          aiRequest,
          memory,
          toolResults: providedToolResults,
          directAnswer: '',
        });
        const content = await this._respondWithRetry({ stream, onDelta, messages, conversationId });
        await this._saveMemory({ aiRequest, memory, toolResults: providedToolResults, finalAnswer: content });
        logger.info('agent.run.done', { conversationId, mode, durationMs: elapsed(), contentLength: content.length });
        return { content, actions, toolResults: providedToolResults };
      }

      const plan = await this._planWithRetry({
        aiRequest,
        memory,
        tools: this._tools.listForPrompt(),
        conversationId,
      });

      logger.info('agent.plan.decided', {
        conversationId,
        planMode: plan.mode,
        toolCallCount: plan.toolCalls?.length ?? 0,
        toolNames: plan.toolCalls?.map((c) => c.toolName) ?? [],
        invalidReason: plan.invalidReason,
      });

      const requestedCalls =
        plan.mode === 'tool' && Array.isArray(plan.toolCalls)
          ? plan.toolCalls.slice(0, this._maxToolCalls)
          : [];

      for (const call of requestedCalls) {
        const execution = await this._tools.execute(call, {
          userId,
          conversationId,
          now: new Date(),
          aiRequest,
          memory,
        });
        actions.push(execution.action);
        toolResults.push(execution.result);
        if (onAction) {
          onAction(execution.action);
        }
      }

      const messages = buildFinalAnswerMessages({
        aiRequest,
        memory,
        toolResults,
        directAnswer: plan.mode === 'answer' ? plan.answer : '',
      });
      const content = await this._respondWithRetry({ stream, onDelta, messages, conversationId });
      await this._saveMemory({ aiRequest, memory, toolResults, finalAnswer: content });

      logger.info('agent.run.done', {
        conversationId,
        mode,
        durationMs: elapsed(),
        actionCount: actions.length,
        contentLength: content.length,
      });

      return { content, actions, toolResults };
    } catch (error) {
      if (isDegradableLlmError(error)) {
        logger.warn('agent.run.degraded_fallback', {
          conversationId,
          mode,
          durationMs: elapsed(),
          error: error.message,
          existingActionCount: actions.length,
          existingToolResultCount: toolResults.length,
        });
        return this._runDegradedFallback({
          aiRequest,
          memory,
          actions,
          toolResults,
          stream,
          onAction,
          onDelta,
          error,
        });
      }

      logger.error('agent.run.failed', {
        conversationId,
        mode,
        durationMs: elapsed(),
        error: error.message,
        stack: error.stack,
      });
      throw error;
    }
  }

  /**
   * Wraps LLM calls with automatic retry on transient errors.
   * Non-retryable errors (bad request, auth, payload too large) are re-thrown immediately.
   */
  async _planWithRetry({ aiRequest, memory, tools, conversationId }) {
    return this._withLlmRetry({
      conversationId,
      operation: 'plan',
      run: () => this._llm.plan({ aiRequest, memory, tools }),
    });
  }

  async _respondWithRetry({ stream, onDelta, messages, conversationId }) {
    const temperature = Number(process.env.LLM_TEMPERATURE || 0.3);
    let emittedDelta = false;

    const trackedOnDelta = stream && onDelta
      ? (delta) => {
          emittedDelta = true;
          onDelta(delta);
        }
      : onDelta;

    return this._withLlmRetry({
      conversationId,
      operation: stream ? 'stream' : 'complete',
      canRetry: () => !stream || !emittedDelta,
      run: async () => {
        if (stream) {
          return this._llm.stream({ messages, onDelta: trackedOnDelta, temperature });
        }
        return this._llm.complete({ messages, temperature });
      },
    });
  }

  async _withLlmRetry({ conversationId, operation, run, canRetry = () => true }) {
    let lastError;

    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
      if (attempt > 0) {
        const delayMs = RETRY_BASE_MS * 2 ** (attempt - 1);
        logger.warn('agent.llm.retry', {
          conversationId,
          operation,
          attempt,
          delayMs,
          error: lastError?.message,
        });
        await sleep(delayMs);
      }

      try {
        return await run();
      } catch (error) {
        lastError = error;
        const retryable = isRetryable(error) && canRetry(error);
        if (!retryable) {
          logger[isDegradableLlmError(error) ? 'warn' : 'error']('agent.llm.non_retryable', {
            conversationId,
            operation,
            attempt,
            error: error.message,
          });
          throw error;
        }
        logger.warn('agent.llm.transient_error', {
          conversationId,
          operation,
          attempt,
          error: error.message,
        });
        if (attempt === MAX_RETRIES) {
          throw error;
        }
      }
    }

    throw lastError;
  }

  async _runDegradedFallback({
    aiRequest,
    memory,
    actions,
    toolResults,
    stream,
    onAction,
    onDelta,
    error,
  }) {
    if (aiRequest.mode === 'agent' && toolResults.length === 0) {
      const fallbackCalls = fallbackToolCalls(aiRequest, this._tools)
        .slice(0, this._maxToolCalls);
      for (const call of fallbackCalls) {
        const execution = await this._tools.execute(call, {
          userId: aiRequest.userId,
          conversationId: aiRequest.conversationId,
          now: new Date(),
          aiRequest,
          memory,
        });
        actions.push(execution.action);
        toolResults.push(execution.result);
        if (onAction) {
          onAction(execution.action);
        }
      }
    }

    const content = buildDegradedFallbackAnswer({
      aiRequest,
      toolResults,
      error,
    });
    if (stream && onDelta) {
      onDelta(content);
    }
    await this._saveMemory({ aiRequest, memory, toolResults, finalAnswer: content });
    return {
      content,
      actions,
      toolResults,
      degraded: true,
    };
  }

  async _saveMemory({ aiRequest, memory, toolResults, finalAnswer }) {
    const requestMessages = aiRequest.messages
      .filter((message) => message.content.trim() !== '')
      .map((message) => ({
        role: message.role,
        content: message.content.slice(0, 1200),
        createdAt: message.createdAt,
      }));

    // Include the assistant's final response so the next request has the
    // complete last turn available for context injection.
    const assistantEntry = finalAnswer
      ? [{ role: 'assistant', content: finalAnswer.slice(0, 1200), createdAt: new Date().toISOString() }]
      : [];

    const lastMessages = [...requestMessages, ...assistantEntry].slice(-16);

    await this._memoryStore.save({
      conversationId: aiRequest.conversationId,
      userId: aiRequest.userId,
      summary: buildMemorySummary({
        previousSummary: memory.summary,
        messages: aiRequest.messages,
        toolResults,
        finalAnswer,
      }),
      lastMessages,
    });

    logger.debug('agent.memory.saved', {
      conversationId: aiRequest.conversationId,
      savedMessageCount: lastMessages.length,
    });
  }
}

function isRetryable(error) {
  if (error.code === 'ECONNRESET' || error.code === 'ENOTFOUND' || error.code === 'ETIMEDOUT') {
    return true;
  }
  if (error.name === 'AbortError') {
    return true;
  }
  // Parse HTTP status from LLM error messages like "LLM provider failed with 503: ..."
  const match = error.message?.match(/LLM provider failed with (\d+)/);
  if (match) {
    return RETRYABLE_LLM_STATUSES.has(Number(match[1]));
  }
  // Timeout messages from _callOpenAiCompatible
  if (error.message?.includes('timed out')) {
    return true;
  }
  return false;
}

function isDegradableLlmError(error) {
  if (isRetryable(error)) {
    return true;
  }
  const message = String(error?.message || '').toLowerCase();
  return (
    message.includes('high demand') ||
    message.includes('temporarily busy') ||
    message.includes('temporarily unavailable') ||
    message.includes('unavailable') ||
    message.includes('overload') ||
    message.includes('timed out')
  );
}

function fallbackToolCalls(aiRequest, tools) {
  const latest = lastUserMessage(aiRequest);
  const text = (latest?.content || '').toLowerCase();
  const calls = [];

  if (tools.has('get_weekly_schedule') && isWeeklyScheduleRequest(text)) {
    calls.push({ toolName: 'get_weekly_schedule', input: {} });
  } else if (tools.has('get_today_schedule') && isScheduleRequest(text)) {
    calls.push({
      toolName: 'get_today_schedule',
      input: dayIndexFromText(text),
    });
  }

  if (tools.has('build_study_plan') && isPlanningRequest(text)) {
    calls.push({
      toolName: 'build_study_plan',
      input: {
        goal: latest?.content?.slice(0, 240) || 'Study session',
        availableMinutes: minutesFromText(text) || 90,
        priority: text.includes('urgent') || text.includes('exam') ? 'high' : 'normal',
      },
    });
  }

  return calls;
}

function buildDegradedFallbackAnswer({ aiRequest, toolResults, error }) {
  const latest = lastUserMessage(aiRequest);
  const text = (latest?.content || '').toLowerCase();
  const preface = providerBusyMessage(error);
  const successfulResults = toolResults.filter((result) => result && result.success);
  const failedResults = toolResults.filter((result) => result && !result.success);

  if (successfulResults.length > 0) {
    const resultLines = successfulResults
      .map((result) => `- ${friendlyToolName(result.toolName)}: ${result.summary}`)
      .join('\n');
    const failedLines = failedResults.length
      ? `\n\nSome local checks failed:\n${failedResults
          .map((result) => `- ${friendlyToolName(result.toolName)}: ${result.summary}`)
          .join('\n')}`
      : '';
    return [
      preface,
      '',
      'I still checked the available StudyFlow data:',
      resultLines,
      failedLines,
      '',
      fallbackNextStep(text),
    ].filter(Boolean).join('\n');
  }

  if (isCapabilityRequest(text)) {
    return [
      preface,
      '',
      'In Agent mode I can help you with:',
      '- Check today or weekly timetable details when your schedule is stored.',
      '- Build a study plan around classes, exams, homework, or free time.',
      '- Break homework into small steps with priorities.',
      '- Suggest revision blocks, active recall prompts, and quick quiz questions.',
      '- Keep context from this chat so follow-up questions make sense.',
      '',
      'Try: "Plan my day around my schedule" or "Build a 90-minute revision plan for math".',
    ].join('\n');
  }

  if (isPlanningRequest(text)) {
    return [
      preface,
      '',
      'Here is a quick fallback study plan:',
      '- 5 min: define the exact outcome and collect materials.',
      '- 25 min: work on the hardest or highest-value part first.',
      '- 5 min: take a real break away from the screen.',
      '- 25 min: solve exercises or rewrite the idea from memory.',
      '- 10 min: self-test and write the next action.',
      '',
      'Send your subject, deadline, and available minutes for a more specific plan.',
    ].join('\n');
  }

  return [
    preface,
    '',
    'I can still help with a simple study workflow:',
    '- Tell me the subject or task.',
    '- Tell me the deadline and how much time you have.',
    '- I will turn it into priorities, focus blocks, and a next step.',
    '',
    'You can also ask what Agent mode can do.',
  ].join('\n');
}

function providerBusyMessage(error) {
  const message = String(error?.message || '').toLowerCase();
  if (message.includes('timed out')) {
    return 'The AI model timed out, so I am using a local StudyFlow fallback.';
  }
  return 'The AI model is busy, so I am using a local StudyFlow fallback.';
}

function fallbackNextStep(text) {
  if (isScheduleRequest(text) && isPlanningRequest(text)) {
    return 'Next step: use those schedule facts to protect class time, then study in 25-minute focus blocks.';
  }
  if (isScheduleRequest(text)) {
    return 'Next step: ask me to build a study plan around this schedule.';
  }
  if (isPlanningRequest(text)) {
    return 'Next step: start with the first focus block, then review what is still unclear.';
  }
  return 'Next step: send the subject, deadline, and available time for a tighter plan.';
}

function isCapabilityRequest(text) {
  return (
    text.includes('what can') ||
    text.includes('what it can do') ||
    text.includes('what can it do') ||
    text.includes('what can you do') ||
    text.includes('help me with') ||
    text.includes('how can you help') ||
    text.includes('capabilities') ||
    text.includes('chenuwa') ||
    text.includes('chnowa') ||
    text.includes('t3awen') ||
    text.includes('t3aweni') ||
    text.includes('t3awni') ||
    text.includes('شنوة') ||
    text.includes('تعاون')
  );
}

function isWeeklyScheduleRequest(text) {
  return (
    text.includes('whole week') ||
    text.includes('weekly') ||
    text.includes('this week') ||
    text.includes('week schedule')
  );
}

function isScheduleRequest(text) {
  return (
    isWeeklyScheduleRequest(text) ||
    text.includes('schedule') ||
    text.includes('class') ||
    text.includes('course') ||
    text.includes('emploi') ||
    text.includes('room') ||
    text.includes('teacher')
  );
}

function isPlanningRequest(text) {
  return (
    text.includes('plan') ||
    text.includes('study') ||
    text.includes('homework') ||
    text.includes('task') ||
    text.includes('organize') ||
    text.includes('revise') ||
    text.includes('exam')
  );
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

function friendlyToolName(toolName) {
  const labels = {
    get_today_schedule: 'Today schedule',
    get_weekly_schedule: 'Weekly schedule',
    build_study_plan: 'Study plan',
  };
  return labels[toolName] || String(toolName || 'StudyFlow action').replaceAll('_', ' ');
}

function lastUserMessage(aiRequest) {
  return [...(aiRequest.messages || [])].reverse().find((message) => message.role === 'user');
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function writeSse(response, payload) {
  if (payload === '[DONE]') {
    response.write('data: [DONE]\n\n');
    return;
  }
  if (payload && typeof payload.event === 'string') {
    response.write(`event: ${payload.event}\n`);
  }
  response.write(`data: ${JSON.stringify(payload)}\n\n`);
}

module.exports = {
  AgentController,
  isRetryable,
  isDegradableLlmError,
  buildDegradedFallbackAnswer,
  writeSse,
};
