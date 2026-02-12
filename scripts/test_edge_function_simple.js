const https = require('https');

// Test the Edge Function directly with your user ID
const testEdgeFunction = () => {
  const data = JSON.stringify({
    title: 'Test Notification',
    body: 'This is a test from the Edge Function!',
    userIds: ['d66a8db3-3432-4953-abf1-c9c968a8b878'], // Your user ID
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
    },
  };

  const req = https.request(options, (res) => {
    let responseData = '';
    
    res.on('data', (chunk) => {
      responseData += chunk;
    });
    
    res.on('end', () => {
      console.log('✅ Edge Function Response:');
      console.log('Status Code:', res.statusCode);
      console.log('Response Body:', responseData);
      
      if (res.statusCode === 200) {
        console.log('🎉 Edge Function is working correctly!');
      } else {
        console.log('❌ Edge Function returned an error');
      }
    });
  });

  req.on('error', (error) => {
    console.error('❌ Request Error:', error);
  });

  req.write(data);
  req.end();
};

console.log('🧪 Testing Edge Function...');
testEdgeFunction(); 