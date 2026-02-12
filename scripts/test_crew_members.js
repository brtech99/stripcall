const { createClient } = require('@supabase/supabase-js');

// Replace with your actual Supabase URL and anon key
const supabaseUrl = 'https://wpytorahphbnzgikowgz.supabase.co';
// You'll need to get the correct anon key from your Supabase dashboard
// or from the environment variables used in your Flutter app
const supabaseKey = process.env.SUPABASE_ANON_KEY || 'YOUR_ANON_KEY_HERE';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testCrewMembers() {
  try {
    console.log('Testing crew members for crew ID 1...');
    
    // Get all crew members for crew 1
    const { data: crewMembers, error } = await supabase
      .from('crewmembers')
      .select('crewmember')
      .eq('crew', '1');
    
    if (error) {
      console.error('Error fetching crew members:', error);
      return;
    }
    
    console.log('Crew members found:', crewMembers.length);
    for (const member of crewMembers) {
      console.log('Crew member ID:', member.crewmember);
    }
    
    // Also check what users exist
    console.log('\nChecking all users...');
    const { data: users, error: userError } = await supabase
      .from('users')
      .select('supabase_id, firstname, lastname');
    
    if (userError) {
      console.error('Error fetching users:', userError);
      return;
    }
    
    console.log('Users found:', users.length);
    for (const user of users) {
      console.log(`User: ${user.firstname} ${user.lastname} (${user.supabase_id})`);
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
}

testCrewMembers(); 