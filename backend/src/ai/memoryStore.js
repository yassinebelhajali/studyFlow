class AgentMemoryStore {
  constructor(store) {
    this._store = store;
  }

  initialize() {
    // No-op. The backing store owns persistence setup.
  }

  async load(conversationId, userId) {
    return this._store.loadAiSession(conversationId, userId);
  }

  async save({ conversationId, userId, summary, lastMessages }) {
    return this._store.saveAiSession({
      conversationId,
      userId,
      summary: typeof summary === 'string' ? summary.slice(0, 2400) : '',
      lastMessages: (lastMessages || []).slice(-16),
    });
  }
}

module.exports = {
  AgentMemoryStore,
};
