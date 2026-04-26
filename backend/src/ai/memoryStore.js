class AgentMemoryStore {
  constructor(store) {
    this._store = store;
  }

  initialize() {
    // No-op. The backing store owns persistence setup.
  }

  async load(conversationId, userId) {
    return normalizeSession(
      await this._store.loadAiSession(conversationId, userId),
      conversationId,
      userId,
    );
  }

  async save({ conversationId, userId, summary, lastMessages }) {
    return this._store.saveAiSession({
      conversationId,
      userId,
      summary: typeof summary === 'string' ? summary.slice(0, 2400) : '',
      lastMessages: normalizeMessages(lastMessages),
    });
  }
}

function normalizeSession(session, conversationId, userId) {
  if (!session || typeof session !== 'object') {
    return {
      conversationId,
      userId,
      summary: '',
      lastMessages: [],
    };
  }

  return {
    ...session,
    conversationId:
      typeof session.conversationId === 'string' && session.conversationId.trim()
        ? session.conversationId
        : conversationId,
    userId:
      typeof session.userId === 'string' && session.userId.trim()
        ? session.userId
        : userId,
    summary: typeof session.summary === 'string' ? session.summary.slice(0, 2400) : '',
    lastMessages: normalizeMessages(session.lastMessages),
  };
}

function normalizeMessages(messages) {
  if (!Array.isArray(messages)) {
    return [];
  }

  return messages
    .filter((message) => message && typeof message === 'object')
    .map((message) => {
      const role = message.role === 'assistant'
        ? 'assistant'
        : message.role === 'user'
          ? 'user'
          : null;
      const content = typeof message.content === 'string' ? message.content.trim() : '';
      if (!role || !content) {
        return null;
      }

      return {
        role,
        content: content.slice(0, 1200),
        createdAt: typeof message.createdAt === 'string' ? message.createdAt : null,
      };
    })
    .filter(Boolean)
    .slice(-16);
}

module.exports = {
  AgentMemoryStore,
};
