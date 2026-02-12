const https = require('https');
const fs = require('fs');

// Load environment variables from .env file (same as run_app.sh)
let envVars = {};
if (fs.existsSync('.env')) {
  const envContent = fs.readFileSync('.env', 'utf8');
  envContent.split('\n').forEach(line => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const [key, ...valueParts] = trimmed.split('=');
      if (key && valueParts.length > 0) {
        envVars[key] = valueParts.join('=');
      }
    }
  });
}

// Get Supabase URL and anon key from environment variables
const SUPABASE_URL = envVars.SUPABASE_URL || 'https://wpytorahphbnzgikowgz.supabase.co';
const SUPABASE_ANON_KEY = envVars.SUPABASE_ANON_KEY;

if (!SUPABASE_ANON_KEY) {
  console.error('Error: SUPABASE_ANON_KEY not found in environment variables.');
  console.error('Please make sure your .env file contains SUPABASE_ANON_KEY.');
  process.exit(1);
}

async function testEdgeFunction() {
  const data = JSON.stringify({
    title: 'Test from Node.js',
    body: 'This is a test notification from the Edge Function!',
    userIds: ['d66a8db3-3432-4953-abf1-c9c968a8b878'], // Your user ID from the logs
    data: {
      type: 'test',
      timestamp: new Date().toISOString(),
    },
  });

  const options = {
    hostname: 'wpytorahphbnzgikowgz.supabase.co',
    port: 443,
    path: '/functions/v1/send-fcm-notification',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      'apikey': SUPABASE_ANON_KEY,
    },
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let responseData = '';
      
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      
      res.on('end', () => {
        console.log('Status Code:', res.statusCode);
        console.log('Response Headers:', res.headers);
        console.log('Response Body:', responseData);
        resolve({ statusCode: res.statusCode, body: responseData });
      });
    });

    req.on('error', (error) => {
      console.error('Request Error:', error);
      reject(error);
    });

    req.write(data);
    req.end();
  });
}

// Run the test
testEdgeFunction()
  .then(result => {
    console.log('Test completed successfully!');
    console.log('Result:', result);
  })
  .catch(error => {
    console.error('Test failed:', error);
  }); 