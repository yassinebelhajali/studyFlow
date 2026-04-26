const fs = require('node:fs');
const path = require('node:path');

// Basic .env.local parser
function loadEnv() {
  const envPath = path.join(process.cwd(), '.env.local');
  if (!fs.existsSync(envPath)) return {};
  const content = fs.readFileSync(envPath, 'utf8');
  const env = {};
  content.split('\n').forEach(line => {
    const [key, ...value] = line.split('=');
    if (key && value) {
      env[key.trim()] = value.join('=').trim();
    }
  });
  return env;
}

const env = loadEnv();

async function listModels() {
  const apiKey = env.GEMINI_API_KEY;
  const baseUrl = env.GEMINI_BASE_URL || 'https://generativelanguage.googleapis.com/v1beta';
  const url = `${baseUrl}/models?key=${apiKey}`;

  try {
    const response = await fetch(url);
    const data = await response.json();
    if (data.models) {
      console.log('Available models:');
      data.models.forEach(m => console.log(`- ${m.name}`));
    } else {
      console.log('No models found or error:', JSON.stringify(data, null, 2));
    }
  } catch (error) {
    console.error('Error listing models:', error);
  }
}

listModels();
