// Using global fetch (Node 18+)
const fs = require('fs');
const path = require('path');

// Try to load .env.local manually
const envPath = path.join(__dirname, '..', 'backend', '.env.local');
const envContent = fs.readFileSync(envPath, 'utf8');
const env = {};
envContent.split('\n').forEach(line => {
    const [key, value] = line.split('=');
    if (key && value) env[key.trim()] = value.trim();
});

const apiKey = 'AlzASyBz6YVY_anJ8dUAf_-DwllzUmaFUFBtCX0';
const model = 'gemini-3-flash-preview';
const baseUrl = env.GEMINI_BASE_URL || 'https://generativelanguage.googleapis.com/v1beta';

async function test() {
    const url = `${baseUrl}/models/${model}:generateContent?key=${apiKey}`;
    console.log(`Testing URL: ${baseUrl}/models/${model}:generateContent?key=***`);
    
    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                contents: [{
                    parts: [{ text: "Hello, are you working?" }]
                }]
            })
        });

        console.log(`Status: ${response.status} ${response.statusText}`);
        const body = await response.text();
        console.log(`Response Body: ${body}`);
    } catch (error) {
        console.error(`Fetch Error: ${error.message}`);
    }
}

test();
