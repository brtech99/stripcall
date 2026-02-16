import '../models/user.dart' as app_models;
import '../services/supabase_manager.dart';
import 'debug_utils.dart';

/// Get the current authenticated user from the database
Future<app_models.User?> getCurrentUser() async {
  try {
    final userId = SupabaseManager().auth.currentUser?.id;
    if (userId == null) return null;

    final response = await SupabaseManager()
        .from('users')
        .select()
        .eq('supabase_id', userId)
        .maybeSingle();

    if (response != null) {
      return app_models.User.fromJson(response);
    }
    return null;
  } catch (e) {
    debugLogError('Error getting current user', e);
    return null;
  }
}

Future<bool> isSuperUser() async {
  try {
    final user = await getCurrentUser();
    return user?.isSuperUser == true;
  } catch (e) {
    debugLogError('Error checking super user status', e);
    return false;
  }
}

Future<bool> isOrganizer() async {
  try {
    final userId = SupabaseManager().auth.currentUser?.id;
    if (userId == null) return false;

    final now = DateTime.now().toUtc();
    final response = await SupabaseManager()
        .from('events')
        .select('id')
        .eq('organizer', userId)
        .gte('enddatetime', now)
        .limit(1);

    return response.isNotEmpty;
  } catch (e) {
    debugLogError('Error checking user permissions', e);
    return false;
  }
}

Future<bool> isCrewChief() async {
  try {
    final userId = SupabaseManager().auth.currentUser?.id;
    if (userId == null) return false;

    final now = DateTime.now().toUtc();
    final response = await SupabaseManager()
        .from('crews') // Changed from 'event_crews' to 'crews'
        .select(
          '*, event:events(id, name, startdatetime, enddatetime)',
        ) // Select specific fields instead of all
        .eq('crew_chief', userId)
        .gte(
          'event.enddatetime',
          now,
        ) // Changed end_date to enddatetime to match schema
        .limit(1);

    return response.isNotEmpty;
  } catch (e) {
    debugLogError('Error checking user permissions for crew', e);
    return false;
  }
}
