const fs = require('node:fs');
const path = require('node:path');

function loadEnvFiles() {
  const backendRoot = path.resolve(__dirname, '..', '..');
  const originalEnvKeys = new Set(Object.keys(process.env));
  const directories = [...new Set([process.cwd(), backendRoot])];

  for (const directory of directories) {
    loadEnvFile(path.resolve(directory, '.env'), {
      canSet: (key) => !originalEnvKeys.has(key) && process.env[key] === undefined,
    });
    loadEnvFile(path.resolve(directory, '.env.local'), {
      canSet: (key) => !originalEnvKeys.has(key),
    });
  }
}

function loadEnvFile(filePath, { canSet = (key) => process.env[key] === undefined } = {}) {
  if (!fs.existsSync(filePath)) {
    return;
  }

  const raw = fs.readFileSync(filePath, 'utf8');
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }

    const separatorIndex = trimmed.indexOf('=');
    if (separatorIndex <= 0) {
      continue;
    }

    const key = trimmed.slice(0, separatorIndex).trim();
    const value = unquoteEnvValue(trimmed.slice(separatorIndex + 1).trim());
    if (canSet(key)) {
      process.env[key] = value;
    }
  }
}

function unquoteEnvValue(value) {
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1);
  }
  return value;
}

module.exports = {
  loadEnvFiles,
};
