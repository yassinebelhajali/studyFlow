const fs = require('fs');
const path = require('path');

const envPath = path.join(__dirname, '..', 'backend', '.env.local');
const envContent = fs.readFileSync(envPath, 'utf8');
const env = {};
envContent.split('\n').forEach(line => {
    const [key, value] = line.split('=');
    if (key && value) env[key.trim()] = value.trim();
});

const apiKey = env.GEMINI_API_KEY;
const baseUrl = env.GEMINI_BASE_URL || 'https://generativelanguage.googleapis.com/v1beta';

async function listModels() {
    const url = `${baseUrl}/models?key=${apiKey}`;
    console.log(`Listing models from: ${baseUrl}/models?key=***`);
    
    try {
        const response = await fetch(url);
        console.log(`Status: ${response.status} ${response.statusText}`);
        const body = await response.json();
        console.log(JSON.stringify(body, null, 2));
    } catch (error) {
        console.error(`Fetch Error: ${error.message}`);
    }
}

listModels();
