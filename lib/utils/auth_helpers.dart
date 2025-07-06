import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as app_models;

/// Get the current authenticated user from the database
Future<app_models.User?> getCurrentUser() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await Supabase.instance.client
        .from('users')
        .select()
        .eq('supabase_id', userId)
        .maybeSingle();

    if (response != null) {
      return app_models.User.fromJson(response);
    }
    return null;
  } catch (e) {
    return null;
  }
}

Future<bool> isSuperUser() async {
  try {
    final user = await getCurrentUser();
    return user?.isSuperUser == true;
  } catch (e) {
    return false;
  }
}

Future<bool> isOrganizer() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;

    final now = DateTime.now().toUtc();
    final response = await Supabase.instance.client
        .from('events')
        .select('id')
        .eq('organizer', userId)
        .gte('enddatetime', now)
        .limit(1);
    
    return response.isNotEmpty;
  } catch (e) {
    return false;
  }
}

Future<bool> isCrewChief() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;

    final now = DateTime.now().toUtc();
    final response = await Supabase.instance.client
        .from('crews')  // Changed from 'event_crews' to 'crews'
        .select('*, event:events(id, name, startdatetime, enddatetime)')  // Select specific fields instead of all
        .eq('crew_chief', userId)
        .gte('event.enddatetime', now)  // Changed end_date to enddatetime to match schema
        .limit(1);
    
    return response.isNotEmpty;
  } catch (e) {
    return false;
  }
} 