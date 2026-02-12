const https = require('https');

// Test the Edge Function with multiple users
const testMultiUserNotifications = () => {
  // Your user ID and a test user ID
  const userIds = [
    'd66a8db3-3432-4953-abf1-c9c968a8b878', // Your user ID
    '04f4cfc6-989c-478d-b677-ea237aa9c25d', // Another user ID from your logs
  ];

  const data = JSON.stringify({
    title: 'Multi-User Test Notification',
    body: 'This notification should be sent to multiple crew members!',
    userIds: userIds,
    data: {
      type: 'test_multi_user',
      timestamp: new Date().toISOString(),
      message: 'Testing Edge Function with multiple users',
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
      console.log('✅ Multi-User Edge Function Test:');
      console.log('Status Code:', res.statusCode);
      console.log('Response Body:', responseData);
      
      if (res.statusCode === 200) {
        console.log('🎉 Edge Function sent notifications to multiple users!');
        console.log('📱 Check your device for the notification');
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

console.log('🧪 Testing Multi-User Notifications...');
console.log('📋 Sending to users:', ['d66a8db3-3432-4953-abf1-c9c968a8b878', '04f4cfc6-989c-478d-b677-ea237aa9c25d']);
testMultiUserNotifications(); 