'use strict';

const LEVELS = { debug: 0, info: 1, warn: 2, error: 3 };
const IS_PROD = process.env.NODE_ENV === 'production';
const currentLevel = LEVELS[(process.env.LOG_LEVEL || 'info').toLowerCase()] ?? LEVELS.info;

function log(level, message, context = {}) {
  if ((LEVELS[level] ?? 0) < currentLevel) {
    return;
  }

  const entry = IS_PROD
    ? JSON.stringify({ ts: new Date().toISOString(), level, message, ...flattenContext(context) })
    : formatDev(level, message, context);

  if (level === 'error') {
    console.error(entry);
  } else if (level === 'warn') {
    console.warn(entry);
  } else {
    console.log(entry);
  }
}

function formatDev(level, message, context) {
  const ts = new Date().toISOString().slice(11, 23); // HH:MM:SS.mmm
  const label = level.toUpperCase().padEnd(5);
  const keys = Object.keys(context);
  const ctx = keys.length ? ' ' + JSON.stringify(context) : '';
  return `${ts} [${label}] ${message}${ctx}`;
}

// In production, avoid nested objects in the log line — most log aggregators
// handle flat key-value pairs better.
function flattenContext(context) {
  const flat = {};
  for (const [key, value] of Object.entries(context)) {
    if (value !== undefined && value !== null) {
      flat[key] = typeof value === 'object' ? JSON.stringify(value) : value;
    }
  }
  return flat;
}

const logger = {
  debug: (msg, ctx = {}) => log('debug', msg, ctx),
  info:  (msg, ctx = {}) => log('info',  msg, ctx),
  warn:  (msg, ctx = {}) => log('warn',  msg, ctx),
  error: (msg, ctx = {}) => log('error', msg, ctx),

  /** Returns a function that reports elapsed ms since this call. */
  startTimer() {
    const start = Date.now();
    return () => Date.now() - start;
  },
};

module.exports = logger;
