const https = require('https');

const EDGE_FUNCTION_URL = 'https://wpytorahphbnzgikowgz.supabase.co/functions/v1/send-fcm-notification';

function keepFunctionWarm() {
  const data = JSON.stringify({
    title: 'Keep Warm',
    body: 'Keeping function warm',
    userIds: ['test'],
    data: { type: 'keep_warm' }
  });

  const options = {
    hostname: 'wpytorahphbnzgikowgz.supabase.co',
    port: 443,
    path: '/functions/v1/send-fcm-notification',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': data.length
    }
  };

  const req = https.request(options, (res) => {
    console.log(`Keep warm request: ${res.statusCode}`);
  });

  req.on('error', (e) => {
    console.log(`Keep warm error: ${e.message}`);
  });

  req.write(data);
  req.end();
}

// Keep function warm every 5 minutes
console.log('Starting function warm-up service...');
keepFunctionWarm(); // Initial call

setInterval(keepFunctionWarm, 5 * 60 * 1000); // Every 5 minutes 