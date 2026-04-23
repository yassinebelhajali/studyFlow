const logger = require('../logger');

class ToolRegistry {
  constructor(tools) {
    this._tools = new Map();
    for (const tool of tools) {
      if (!tool || typeof tool.name !== 'string' || this._tools.has(tool.name)) {
        throw new Error(`Invalid or duplicate tool registration: ${tool && tool.name}`);
      }
      this._tools.set(tool.name, tool);
    }
  }

  listForPrompt() {
    return [...this._tools.values()].map((tool) => ({
      name: tool.name,
      description: tool.description,
      inputSchema: tool.inputSchema || {},
    }));
  }

  has(name) {
    return this._tools.has(name);
  }

  validateCall(call) {
    if (!call || typeof call !== 'object') {
      return { ok: false, error: 'Tool call must be an object' };
    }

    if (typeof call.toolName !== 'string' || call.toolName.trim() === '') {
      return { ok: false, error: 'Tool call is missing toolName' };
    }

    const toolName = call.toolName.trim();
    const tool = this._tools.get(toolName);
    if (!tool) {
      return { ok: false, error: `Unknown tool "${toolName}"` };
    }

    const input = call.input && typeof call.input === 'object' ? call.input : {};
    if (typeof tool.validateInput === 'function') {
      const validation = tool.validateInput(input);
      if (!validation.ok) {
        return { ok: false, error: validation.error, toolName };
      }
      return { ok: true, toolName, input: validation.value || {}, tool };
    }

    return { ok: true, toolName, input, tool };
  }

  async execute(call, context) {
    const validation = this.validateCall(call);

    if (!validation.ok) {
      const toolName = validation.toolName || (call && call.toolName) || 'unknown';
      logger.warn('tool.validation.failed', {
        conversationId: context?.conversationId,
        toolName,
        error: validation.error,
        inputKeys: call?.input ? Object.keys(call.input) : [],
      });

      const result = {
        toolName,
        success: false,
        summary: validation.error,
        data: {},
      };
      return {
        action: createCompletedAction({
          toolName,
          input: call?.input || {},
          status: 'failed',
          errorMessage: validation.error,
          result,
        }),
        result,
      };
    }

    const elapsed = logger.startTimer();
    logger.info('tool.execute.start', {
      conversationId: context?.conversationId,
      toolName: validation.toolName,
      inputKeys: Object.keys(validation.input),
    });

    const action = {
      id: newId('action'),
      toolName: validation.toolName,
      input: validation.input,
      status: 'running',
      createdAt: new Date().toISOString(),
    };

    try {
      const result = normalizeToolResult(
        validation.toolName,
        await validation.tool.execute(validation.input, context),
      );

      const durationMs = elapsed();
      if (result.success) {
        logger.info('tool.execute.done', {
          conversationId: context?.conversationId,
          toolName: validation.toolName,
          durationMs,
          summaryLength: result.summary.length,
        });
      } else {
        logger.warn('tool.execute.returned_failure', {
          conversationId: context?.conversationId,
          toolName: validation.toolName,
          durationMs,
          summary: result.summary,
        });
      }

      return {
        action: {
          ...action,
          status: result.success ? 'succeeded' : 'failed',
          completedAt: new Date().toISOString(),
          result,
          errorMessage: result.success ? null : result.summary,
        },
        result,
      };
    } catch (error) {
      logger.error('tool.execute.threw', {
        conversationId: context?.conversationId,
        toolName: validation.toolName,
        durationMs: elapsed(),
        error: error.message,
        stack: error.stack,
      });

      const result = {
        toolName: validation.toolName,
        success: false,
        summary: `Tool failed: ${error.message}`,
        data: {},
      };
      return {
        action: {
          ...action,
          status: 'failed',
          completedAt: new Date().toISOString(),
          result,
          errorMessage: error.message,
        },
        result,
      };
    }
  }
}

function normalizeToolResult(toolName, result) {
  if (!result || typeof result !== 'object') {
    return {
      toolName,
      success: false,
      summary: 'Tool returned an invalid result',
      data: {},
    };
  }

  return {
    toolName,
    success: result.success === true,
    summary: typeof result.summary === 'string' ? result.summary.slice(0, 4000) : '',
    data: result.data && typeof result.data === 'object' ? result.data : {},
  };
}

function createCompletedAction({ toolName, input, status, errorMessage, result }) {
  const now = new Date().toISOString();
  return {
    id: newId('action'),
    toolName,
    input,
    status,
    createdAt: now,
    completedAt: now,
    result,
    errorMessage,
  };
}

function newId(prefix) {
  return `${prefix}_${Date.now()}_${Math.random().toString(16).slice(2)}`;
}

module.exports = {
  ToolRegistry,
};
