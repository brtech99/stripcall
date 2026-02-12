const { Resend } = require('resend');

// Test Resend API key
async function testResend() {
  try {
    const resend = new Resend(process.env.RESEND_API_KEY || 'your-api-key-here');
    
    console.log('Testing Resend connection...');
    
    const { data, error } = await resend.emails.send({
      from: 'noreply@stripcall.us',
      to: ['test@example.com'],
      subject: 'Test Email from Resend',
      html: '<p>This is a test email to verify Resend is working.</p>'
    });

    if (error) {
      console.error('Resend error:', error);
      return false;
    }

    console.log('Resend test successful:', data);
    return true;
  } catch (error) {
    console.error('Resend test failed:', error);
    return false;
  }
}

testResend(); 