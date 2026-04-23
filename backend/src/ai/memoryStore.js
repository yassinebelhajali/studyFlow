class AgentMemoryStore {
  constructor(db) {
    this._db = db;
    this._upsert = null;
    this._select = null;
  }

  initialize() {
    this._db.exec(`
      CREATE TABLE IF NOT EXISTS ai_agent_sessions (
        conversation_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        summary TEXT NOT NULL DEFAULT '',
        last_messages_json TEXT NOT NULL DEFAULT '[]',
        updated_at TEXT NOT NULL,
        PRIMARY KEY (conversation_id, user_id)
      );

      CREATE INDEX IF NOT EXISTS idx_ai_agent_sessions_user_updated
      ON ai_agent_sessions(user_id, updated_at);
    `);

    this._upsert = this._db.prepare(`
      INSERT INTO ai_agent_sessions
        (conversation_id, user_id, summary, last_messages_json, updated_at)
      VALUES
        (@conversationId, @userId, @summary, @lastMessagesJson, @updatedAt)
      ON CONFLICT(conversation_id, user_id) DO UPDATE SET
        summary = excluded.summary,
        last_messages_json = excluded.last_messages_json,
        updated_at = excluded.updated_at
    `);
    this._select = this._db.prepare(`
      SELECT conversation_id, user_id, summary, last_messages_json, updated_at
      FROM ai_agent_sessions
      WHERE conversation_id = ? AND user_id = ?
    `);
  }

  load(conversationId, userId) {
    const row = this._select.get(conversationId, userId);
    if (!row) {
      return {
        conversationId,
        userId,
        summary: '',
        lastMessages: [],
      };
    }

    return {
      conversationId: row.conversation_id,
      userId: row.user_id,
      summary: row.summary || '',
      lastMessages: parseJsonArray(row.last_messages_json),
      updatedAt: row.updated_at,
    };
  }

  save({ conversationId, userId, summary, lastMessages }) {
    this._upsert.run({
      conversationId,
      userId,
      summary: typeof summary === 'string' ? summary.slice(0, 2400) : '',
      lastMessagesJson: JSON.stringify((lastMessages || []).slice(-16)),
      updatedAt: new Date().toISOString(),
    });
  }
}

function parseJsonArray(raw) {
  try {
    const decoded = JSON.parse(raw);
    return Array.isArray(decoded) ? decoded : [];
  } catch (_error) {
    return [];
  }
}

module.exports = {
  AgentMemoryStore,
};
