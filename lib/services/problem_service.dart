import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/problem_with_details.dart';
import 'notification_service.dart';
import '../utils/debug_utils.dart';

class ProblemService {
  static final ProblemService _instance = ProblemService._internal();
  factory ProblemService() => _instance;
  ProblemService._internal();

  Future<List<ProblemWithDetails>> loadProblems({
    required int eventId,
    required String userId,
    int? crewId,
    bool isSuperUser = false,
  }) async {
    try {
      print('DEBUG: loadProblems START (isSuperUser=$isSuperUser, crewId=$crewId)');
      final startTime = DateTime.now();

      // Super users bypass crew membership check when viewing a specific crew
      if (isSuperUser && crewId != null) {
        print('DEBUG: Super user viewing crew $crewId, loading crew problems only');
        final queryStart = DateTime.now();

        final response = await Supabase.instance.client
            .from('problem')
            .select('''
              *,
              symptom_data:symptom(id, symptomstring),
              originator_data:originator(supabase_id, firstname, lastname),
              actionby_data:actionby(supabase_id, firstname, lastname),
              action_data:action(id, actionstring),
              messages_data:messages(*)
            ''')
            .eq('event', eventId)
            .eq('crew', crewId)
            .order('startdatetime', ascending: false);

        final afterQuery = DateTime.now();
        print('DEBUG: Super user crew query completed in ${afterQuery.difference(queryStart).inMilliseconds}ms, count=${response.length}');

        final problems = <ProblemWithDetails>[];
        for (final json in response) {
          try {
            final problem = ProblemWithDetails.fromJson(json);

            // Filter out resolved problems that are older than 5 minutes
            if (problem.resolvedDateTimeParsed != null) {
              final resolvedTime = problem.resolvedDateTimeParsed!;
              final now = DateTime.now();
              final minutesSinceResolved = now.difference(resolvedTime).inMinutes;

              if (minutesSinceResolved >= 5) {
                continue;
              }
            }

            problems.add(problem);
          } catch (e) {
            debugLogError('Error parsing problem', e);
            print('DEBUG: Failed JSON: $json');
          }
        }

        print('DEBUG: Successfully parsed ${problems.length} problems out of ${response.length} total');
        print('DEBUG: Total loadProblems time (super user): ${DateTime.now().difference(startTime).inMilliseconds}ms');
        return problems;
      }

      // First, check if user is part of a crew for this event
      print('DEBUG: Checking crew membership for user=$userId, crewId=$crewId');
      final crewMemberResponse = crewId != null ? await Supabase.instance.client
          .from('crewmembers')
          .select('crew')
          .eq('crewmember', userId)
          .eq('crew', crewId)
          .maybeSingle() : null;

      final afterCrewCheck = DateTime.now();
      print('DEBUG: Crew check completed in ${afterCrewCheck.difference(startTime).inMilliseconds}ms, result=${crewMemberResponse != null}');

      // If user is not part of any crew OR not part of the specified crew, only show their own problems
      if (crewId == null || crewMemberResponse == null) {
        // User is not part of this crew, only show problems they created
        print('DEBUG: User not in crew, loading only their own problems');
        final queryStart = DateTime.now();

        final response = await Supabase.instance.client
            .from('problem')
            .select('''
              *,
              symptom_data:symptom(id, symptomstring),
              originator_data:originator(supabase_id, firstname, lastname),
              actionby_data:actionby(supabase_id, firstname, lastname),
              action_data:action(id, actionstring),
              messages_data:messages(*)
            ''')
            .eq('event', eventId)
            .eq('originator', userId)
            .order('startdatetime', ascending: false);

        final afterQuery = DateTime.now();
        print('DEBUG: Own problems query completed in ${afterQuery.difference(queryStart).inMilliseconds}ms, count=${response.length}');

        final problems = <ProblemWithDetails>[];
        for (final json in response) {
          try {
            final problem = ProblemWithDetails.fromJson(json);

            // Filter out resolved problems that are older than 5 minutes
            if (problem.resolvedDateTimeParsed != null) {
              final resolvedTime = problem.resolvedDateTimeParsed!;
              final now = DateTime.now();
              final minutesSinceResolved = now.difference(resolvedTime).inMinutes;

              if (minutesSinceResolved >= 5) {
                continue;
              }
            }

            problems.add(problem);
          } catch (e) {
            debugLogError('Error parsing problem', e);
            print('DEBUG: Failed JSON: $json');
          }
        }

        print('DEBUG: Successfully parsed ${problems.length} problems out of ${response.length} total');
        print('DEBUG: Total loadProblems time (non-crew): ${DateTime.now().difference(startTime).inMilliseconds}ms');
        return problems;
      } else {
        // User is part of the crew: show crew's problems + any problems user created for other crews
        print('DEBUG: User is in crew $crewId, loading crew problems + user\'s problems for other crews');
        final queryStart = DateTime.now();

        final response = await Supabase.instance.client
            .from('problem')
            .select('''
              *,
              symptom_data:symptom(id, symptomstring),
              originator_data:originator(supabase_id, firstname, lastname),
              actionby_data:actionby(supabase_id, firstname, lastname),
              action_data:action(id, actionstring),
              messages_data:messages(*)
            ''')
            .eq('event', eventId)
            .or('crew.eq.$crewId,originator.eq.$userId')
            .order('startdatetime', ascending: false);

        final afterQuery = DateTime.now();
        print('DEBUG: Crew problems query completed in ${afterQuery.difference(queryStart).inMilliseconds}ms, count=${response.length}');

        final problems = <ProblemWithDetails>[];
        final seenProblemIds = <int>{}; // Track IDs to avoid duplicates

        for (final json in response) {
          try {
            final problem = ProblemWithDetails.fromJson(json);

            // Skip if we've already added this problem (avoid duplicates when user reports to their own crew)
            if (seenProblemIds.contains(problem.id)) {
              continue;
            }
            seenProblemIds.add(problem.id);

            // Filter out resolved problems that are older than 5 minutes
            if (problem.resolvedDateTimeParsed != null) {
              final resolvedTime = problem.resolvedDateTimeParsed!;
              final now = DateTime.now();
              final minutesSinceResolved = now.difference(resolvedTime).inMinutes;

              if (minutesSinceResolved >= 5) {
                continue;
              }
            }

            problems.add(problem);
          } catch (e) {
            debugLogError('Error parsing problem', e);
            print('DEBUG: Failed JSON: $json');
          }
        }

        print('DEBUG: Successfully parsed ${problems.length} unique problems out of ${response.length} total');
        print('DEBUG: Total loadProblems time (crew member): ${DateTime.now().difference(startTime).inMilliseconds}ms');
        return problems;
      }
    } catch (e) {
      debugLogError('Failed to load problems', e);
      throw Exception('Failed to load problems: $e');
    }
  }

  Future<Map<int, List<Map<String, dynamic>>>> loadResponders(List<ProblemWithDetails> problems) async {
    try {
      if (problems.isEmpty) return {};

      final problemIds = problems.map((p) => p.id).toList();
      final response = await Supabase.instance.client
          .from('responders')
          .select('problem, user_id, responded_at, user:user_id(firstname, lastname)')
          .inFilter('problem', problemIds);

      print('DEBUG loadResponders: Raw response = $response');

      final respondersMap = <int, List<Map<String, dynamic>>>{};
      for (final responder in response) {
        final problemId = responder['problem'] as int;
        if (!respondersMap.containsKey(problemId)) {
          respondersMap[problemId] = [];
        }
        respondersMap[problemId]!.add(responder);
      }

      print('DEBUG loadResponders: Final map = $respondersMap');
      return respondersMap;
    } catch (e) {
      print('DEBUG loadResponders: Error = $e');
      return {};
    }
  }

  Future<void> goOnMyWay(int problemId, String userId) async {
    try {
      // Get problem details for notification (including originator)
      final problemResponse = await Supabase.instance.client
          .from('problem')
          .select('crew, strip, originator')
          .eq('id', problemId)
          .single();

      // Get responder name
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('firstname, lastname')
          .eq('supabase_id', userId)
          .single();

      await Supabase.instance.client.from('responders').insert({
        'problem': problemId,
        'user_id': userId,
        'responded_at': DateTime.now().toUtc().toIso8601String(),
      });

      final responderName = '${userResponse['firstname']} ${userResponse['lastname']}';
      final strip = problemResponse['strip'] as String;
      final crewId = problemResponse['crew'] as int;
      final reporterId = problemResponse['originator'] as String?;

      // Send crew message
      try {
        await Supabase.instance.client.from('crew_messages').insert({
          'crew': crewId,
          'author': userId,
          'message': '$responderName is on the way',
        });
      } catch (crewMessageError) {
        debugLogError('Failed to send crew message (responder was recorded successfully)', crewMessageError);
        // Continue - responder was recorded successfully even if crew message failed
      }

      // Send notification using Edge Function (include reporter so they know someone is coming)
      try {

        await NotificationService().sendCrewNotification(
          title: 'Crew Member En Route',
          body: '$responderName is en route to Strip $strip',
          crewId: crewId.toString(),
          senderId: userId,
          data: {
            'type': 'problem_response',
            'problemId': problemId.toString(),
            'crewId': crewId.toString(),
            'strip': strip,
          },
          includeReporter: true, // Include reporter so they know help is coming
          reporterId: reporterId,
        );
      } catch (notificationError) {
        debugLogError('Failed to send notification (responder was recorded successfully)', notificationError);
        // Continue - responder was recorded successfully even if notification failed
      }
    } catch (e) {
      debugLogError('Error updating status (goOnMyWay)', e);
      if (e.toString().contains('duplicate key') || e.toString().contains('UNIQUE')) {
        throw Exception('You are already en route');
      }
      throw Exception('Failed to update status: $e');
    }
  }

  Future<Map<String, dynamic>?> loadMissingSymptomData(int symptomId) async {
    try {
      final symptomResponse = await Supabase.instance.client
          .from('symptom')
          .select('id, symptomstring')
          .eq('id', symptomId)
          .maybeSingle();

      return symptomResponse;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> loadMissingOriginatorData(String originatorId) async {
    try {
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('supabase_id, firstname, lastname')
          .eq('supabase_id', originatorId)
          .maybeSingle();

      return userResponse;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> loadMissingResolverData(String actionById) async {
    try {
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('supabase_id, firstname, lastname')
          .eq('supabase_id', actionById)
          .maybeSingle();

      return userResponse;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> checkForNewProblems({
    required int eventId,
    required String userId,
    required DateTime since,
    int? crewId,
    bool isSuperUser = false,
  }) async {
    try {
      // Use same filtering logic as loadProblems
      const selectFields = '''
        *,
        symptom_data:symptom(id, symptomstring),
        originator_data:originator(supabase_id, firstname, lastname),
        actionby_data:actionby(supabase_id, firstname, lastname),
        action_data:action(id, actionstring),
        messages_data:messages(*)
      ''';

      // Super users viewing a specific crew: only that crew's new problems
      if (isSuperUser && crewId != null) {
        final response = await Supabase.instance.client
            .from('problem')
            .select(selectFields)
            .eq('event', eventId)
            .eq('crew', crewId)
            .gt('startdatetime', since.toIso8601String())
            .order('startdatetime', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      }

      // Check if user is a crew member
      final crewMemberResponse = crewId != null ? await Supabase.instance.client
          .from('crewmembers')
          .select('crew')
          .eq('crewmember', userId)
          .eq('crew', crewId)
          .maybeSingle() : null;

      // Non-crew member or no crew: only their own new problems
      if (crewId == null || crewMemberResponse == null) {
        final response = await Supabase.instance.client
            .from('problem')
            .select(selectFields)
            .eq('event', eventId)
            .eq('originator', userId)
            .gt('startdatetime', since.toIso8601String())
            .order('startdatetime', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      }

      // Crew member: crew's problems + their problems for other crews
      final response = await Supabase.instance.client
          .from('problem')
          .select(selectFields)
          .eq('event', eventId)
          .or('crew.eq.$crewId,originator.eq.$userId')
          .gt('startdatetime', since.toIso8601String())
          .order('startdatetime', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugLogError('Error checking for new problems', e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> checkForNewMessages({
    required DateTime since,
    required List<int> problemIds,
  }) async {
    try {
      if (problemIds.isEmpty) return [];

      final problemIdsStr = problemIds.join(',');

      final newMessages = await Supabase.instance.client
          .rpc('get_new_messages', params: {
            'since_time': since.toIso8601String(),
            'problem_ids': problemIdsStr,
          });

      return List<Map<String, dynamic>>.from(newMessages ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Check for updates to existing problems (resolution status, action changes, etc.)
  Future<List<Map<String, dynamic>>> checkForProblemUpdates({
    required DateTime since,
    required List<int> problemIds,
  }) async {
    try {
      if (problemIds.isEmpty) return [];

      const selectFields = '''
        id,
        enddatetime,
        action,
        actionby,
        action_data:action(id, actionstring),
        actionby_data:actionby(supabase_id, firstname, lastname)
      ''';

      // Query for problems that have been updated since the last check
      // Build an OR condition for problem IDs since in_() is not available in older postgrest
      final idConditions = problemIds.map((id) => 'id.eq.$id').join(',');

      final response = await Supabase.instance.client
          .from('problem')
          .select(selectFields)
          .or(idConditions)
          .not('enddatetime', 'is', null) // Only get resolved problems
          .gte('enddatetime', since.toIso8601String());

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugLogError('Error checking for problem updates', e);
      return [];
    }
  }

  /// Load messages for a specific problem
  Future<List<Map<String, dynamic>>> loadMessagesForProblem(int problemId) async {
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select('*')
          .eq('problem', problemId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> checkForResolvedProblems({
    required int eventId,
    required int crewId,
    required DateTime since,
  }) async {
    try {
      // Use direct query to get full resolution data including action_data and actionby_data
      const selectFields = '''
        id,
        enddatetime,
        action,
        actionby,
        action_data:action(id, actionstring),
        actionby_data:actionby(supabase_id, firstname, lastname)
      ''';

      final response = await Supabase.instance.client
          .from('problem')
          .select(selectFields)
          .eq('event', eventId)
          .eq('crew', crewId)
          .not('enddatetime', 'is', null)
          .gte('enddatetime', since.toIso8601String());

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugLogError('Error checking for resolved problems', e);
      return [];
    }
  }

  String getProblemStatus(ProblemWithDetails problem, Map<int, List<Map<String, dynamic>>> responders) {
    if (problem.isResolved) return 'resolved';
    if (responders.containsKey(problem.id) && responders[problem.id]!.isNotEmpty) {
      return 'en_route';
    }
    return 'new';
  }

  /// Change the symptom of a problem, recording the old value in oldproblemsymptom
  Future<void> changeSymptom({
    required int problemId,
    required int oldSymptomId,
    required int newSymptomId,
    required String userId,
  }) async {
    try {
      // Record the old symptom in oldproblemsymptom table
      await Supabase.instance.client.from('oldproblemsymptom').insert({
        'problem': problemId,
        'oldsymptom': oldSymptomId,
        'changedby': userId,
        'changedat': DateTime.now().toUtc().toIso8601String(),
      });

      // Update the problem with the new symptom
      await Supabase.instance.client.from('problem').update({
        'symptom': newSymptomId,
      }).eq('id', problemId);
    } catch (e) {
      debugLogError('Failed to change symptom', e);
      throw Exception('Failed to change symptom: $e');
    }
  }

  /// Load the symptom change history for a problem
  Future<List<Map<String, dynamic>>> loadSymptomHistory(int problemId) async {
    try {
      final response = await Supabase.instance.client
          .from('oldproblemsymptom')
          .select('''
            *,
            symptom:oldsymptom(id, symptomstring),
            user:changedby(supabase_id, firstname, lastname)
          ''')
          .eq('problem', problemId)
          .order('changedat', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugLogError('Failed to load symptom history', e);
      return [];
    }
  }
}
