// Maximum total chars sent to the LLM across all conversation messages.
// ~20 000 chars ≈ 5 000 tokens — safe headroom for every supported model.
const CONTEXT_CHAR_BUDGET = 20_000;

// Number of user turns the client must supply before we trust the client's
// history fully and skip injecting stored memory messages.
const MIN_CLIENT_USER_TURNS_FOR_FULL_TRUST = 3;

function buildFinalAnswerMessages({ aiRequest, memory, toolResults, directAnswer }) {
  const messages = [
    {
      role: 'system',
      content: [
        'You are StudyFlow Agent, a practical study assistant for university students.',
        'Return a clean final response that turns the request into a concrete next step.',
        'Use short sections or bullets when a plan, schedule, checklist, or explanation would be easier to scan.',
        'Match the student language when it is clear from the latest message.',
        'Only mention actions that appear in trusted tool results.',
        'If a tool failed, explain what can still be answered and avoid pretending the action succeeded.',
        'When schedule or planning tool results are present, treat them as the source of truth and include exact times, rooms, priorities, or block lengths when available.',
        'If critical information is missing, ask one focused follow-up question after giving the best useful partial answer.',
        'Keep the response concise, concrete, and encouraging without generic filler.',
      ].join(' '),
    },
  ];

  if (memory.summary) {
    messages.push({
      role: 'system',
      content: `Session memory summary:\n${memory.summary}`,
    });
  }

  const trustedContext = toolResults
    .map((result) => {
      const status = result.success ? 'success' : 'failed';
      return `${result.toolName} (${status}): ${result.summary}`;
    })
    .join('\n');

  if (trustedContext) {
    messages.push({
      role: 'system',
      content: `Trusted tool/action results:\n${trustedContext}`,
    });
  }

  if (directAnswer) {
    messages.push({
      role: 'system',
      content: `Planner direct-answer guidance:\n${directAnswer}`,
    });
  }

  messages.push(...buildConversationContext(aiRequest, memory));
  return messages;
}

function buildChatMessages({ aiRequest, memory }) {
  const messages = [
    {
      role: 'system',
      content: [
        'You are StudyFlow Chat, a direct study assistant for explanations, summaries, quizzes, homework breakdowns, and revision advice.',
        'Answer directly and do not claim to execute tools or app actions.',
        'If the student asks for schedule facts or app data, explain that Agent mode can check available StudyFlow actions.',
        'Use concise steps, examples, or mini-quizzes when they help the student act immediately.',
        'Match the student language when it is clear from the latest message.',
      ].join(' '),
    },
  ];
  if (memory.summary) {
    messages.push({
      role: 'system',
      content: `Session memory summary:\n${memory.summary}`,
    });
  }
  messages.push(...buildConversationContext(aiRequest, memory));
  return messages;
}

/**
 * Build the ordered user/assistant turns to include in the LLM prompt.
 *
 * Strategy:
 *  - If the client sends ≥ MIN_CLIENT_USER_TURNS_FOR_FULL_TRUST user turns,
 *    their history is complete enough — use it directly with a char budget cap.
 *  - Otherwise the client is on a new device or just started a fresh session.
 *    Inject stored messages from memory first, then append the client's new
 *    message(s), de-duplicating any overlap at the boundary.
 */
function buildConversationContext(aiRequest, memory) {
  const clientMessages = toProviderConversation(aiRequest.messages);
  const clientUserTurns = clientMessages.filter((m) => m.role === 'user').length;

  if (clientUserTurns >= MIN_CLIENT_USER_TURNS_FOR_FULL_TRUST) {
    return applyContextBudget(clientMessages);
  }

  const storedMessages = buildStoredContext(memory.lastMessages);
  if (storedMessages.length === 0) {
    return applyContextBudget(clientMessages);
  }

  const merged = deduplicateTail([...storedMessages, ...clientMessages]);
  return applyContextBudget(merged.slice(-20));
}

/** Convert stored lastMessages entries into provider-safe message objects. */
function buildStoredContext(lastMessages) {
  if (!Array.isArray(lastMessages) || lastMessages.length === 0) {
    return [];
  }
  return lastMessages
    .filter(
      (m) =>
        (m.role === 'user' || m.role === 'assistant') &&
        typeof m.content === 'string' &&
        m.content.trim(),
    )
    .map((m) => ({ role: m.role, content: m.content.slice(0, 1200) }));
}

/**
 * Remove exact consecutive duplicates that appear at the boundary between
 * stored messages and new client messages (same role + same content).
 */
function deduplicateTail(messages) {
  if (messages.length < 2) {
    return messages;
  }
  const result = [messages[0]];
  for (let i = 1; i < messages.length; i++) {
    const prev = result[result.length - 1];
    const curr = messages[i];
    if (prev.role === curr.role && prev.content === curr.content) {
      continue;
    }
    result.push(curr);
  }
  return result;
}

/**
 * Walk from newest to oldest, accumulating messages until the char budget is
 * exhausted.  Always includes the most-recent message regardless of size.
 */
function applyContextBudget(messages) {
  let totalChars = 0;
  const result = [];
  for (const msg of [...messages].reverse()) {
    const chars = (msg.content || '').length;
    if (result.length > 0 && totalChars + chars > CONTEXT_CHAR_BUDGET) {
      break;
    }
    result.unshift(msg);
    totalChars += chars;
  }
  return result;
}

function buildMemorySummary({ previousSummary, messages, toolResults, finalAnswer }) {
  const recentUserMessages = messages
    .filter((message) => message.role === 'user')
    .slice(-3)
    .map((message) => message.content.trim())
    .filter(Boolean);

  const toolNames = toolResults
    .filter((result) => result.success)
    .map((result) => result.toolName);

  const lines = [];

  if (previousSummary) {
    // Keep prior context but cap it so there is always room for new entries
    lines.push(previousSummary.slice(-1200));
  }
  if (recentUserMessages.length) {
    lines.push(`[User asked]: ${recentUserMessages.join(' | ')}`);
  }
  if (toolNames.length) {
    lines.push(`[Tools used]: ${[...new Set(toolNames)].join(', ')}`);
  }
  if (finalAnswer) {
    lines.push(`[Last reply]: ${finalAnswer.slice(0, 400)}`);
  }

  return lines.join('\n').slice(-2400);
}

function toProviderConversation(messages) {
  return messages
    .filter((message) => {
      if (message.role === 'tool') {
        return false;
      }
      if (message.role === 'assistant' && message.content.trim() === '') {
        return false;
      }
      return message.content.trim() !== '';
    })
    .slice(-20)
    .map((message) => ({
      role:
        message.role === 'system'
          ? 'system'
          : message.role === 'assistant'
            ? 'assistant'
            : 'user',
      content: message.content,
    }));
}

module.exports = {
  buildChatMessages,
  buildFinalAnswerMessages,
  buildMemorySummary,
  toProviderConversation,
  // Exported for testing
  buildConversationContext,
  applyContextBudget,
};
