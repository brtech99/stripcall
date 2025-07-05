const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Force 1st Gen functions
const { onRequest } = require('firebase-functions/v1/https');

exports.testNotification = onRequest(async (req, res) => {
  try {
    // Enable CORS
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    // Handle preflight requests
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    const { token, title, body } = req.body;
    
    if (!token) {
      res.status(400).json({ error: 'Token is required' });
      return;
    }
    
    // Use FCM V1 API with Firebase Admin SDK
    const message = {
      notification: {
        title: title || 'Test Notification',
        body: body || 'This is a test notification from Firebase Function!',
      },
      token: token,
      data: {
        type: 'test',
        timestamp: new Date().toISOString(),
      },
    };

    console.log('Sending FCM message:', message);

    const response = await admin.messaging().send(message);
    
    console.log('Successfully sent message:', response);
    
    res.status(200).json({ 
      success: true, 
      messageId: response,
      message: 'Notification sent successfully!' 
    });
    
  } catch (error) {
    console.error('Error sending notification:', error);
    res.status(500).json({ 
      error: 'Failed to send notification', 
      details: error.message 
    });
  }
}); 