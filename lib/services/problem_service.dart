import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/problem_with_details.dart';
import 'notification_service.dart';
import '../utils/debug_utils.dart';

class ProblemService {
  static final ProblemService _instance = ProblemService._internal();
  factory ProblemService() => _instance;
  ProblemService._internal();

  static const _problemSelectFields = '''
    id, event, crew, originator, strip, symptom, startdatetime, action, actionby, enddatetime, notes, reporter_phone,
    symptom_data:symptom(id, symptomstring),
    originator_data:originator(supabase_id, firstname, lastname),
    actionby_data:actionby(supabase_id, firstname, lastname),
    action_data:action(id, actionstring),
    messages_data:messages(*)
  ''';

  /// Parse raw JSON rows into [ProblemWithDetails], filtering out resolved
  /// problems older than 5 minutes. When [deduplicate] is true, duplicate
  /// problem IDs are skipped (used for the OR query that may return the same
  /// problem via both crew and originator match).
  List<ProblemWithDetails> _parseAndFilterProblems(
    List<dynamic> response, {
    bool deduplicate = false,
  }) {
    final problems = <ProblemWithDetails>[];
    final seenIds = <int>{};

    for (final json in response) {
      try {
        final problem = ProblemWithDetails.fromJson(json);

        if (deduplicate) {
          if (seenIds.contains(problem.id)) continue;
          seenIds.add(problem.id);
        }

        // Filter out resolved problems older than 5 minutes
        if (problem.resolvedDateTimeParsed != null) {
          final minutesSinceResolved = DateTime.now()
              .difference(problem.resolvedDateTimeParsed!)
              .inMinutes;
          if (minutesSinceResolved >= 5) continue;
        }

        problems.add(problem);
      } catch (e) {
        debugLogError('Error parsing problem', e);
        debugLog('Failed JSON: $json');
      }
    }

    debugLog(
      'Parsed ${problems.length} problems out of ${response.length} total',
    );
    return problems;
  }

  Future<List<ProblemWithDetails>> loadProblems({
    required int eventId,
    required String userId,
    int? crewId,
    bool isSuperUser = false,
  }) async {
    try {
      debugLog('loadProblems START (isSuperUser=$isSuperUser, crewId=$crewId)');
      final startTime = DateTime.now();

      // Super users bypass crew membership check when viewing a specific crew
      if (isSuperUser && crewId != null) {
        debugLog('Super user viewing crew $crewId, loading crew problems only');
        final queryStart = DateTime.now();

        final response = await Supabase.instance.client
            .from('problem')
            .select(_problemSelectFields)
            .eq('event', eventId)
            .eq('crew', crewId)
            .order('startdatetime', ascending: false);

        final afterQuery = DateTime.now();
        debugLog(
          'Super user crew query completed in ${afterQuery.difference(queryStart).inMilliseconds}ms, count=${response.length}',
        );

        final problems = _parseAndFilterProblems(response);
        final enrichedProblems = await enrichWithSmsReporterNames(problems);

        debugLog(
          'Total loadProblems time (super user): ${DateTime.now().difference(startTime).inMilliseconds}ms',
        );
        return enrichedProblems;
      }

      // First, check if user is part of a crew for this event
      debugLog('Checking crew membership for user=$userId, crewId=$crewId');
      final crewMemberResponse = crewId != null
          ? await Supabase.instance.client
                .from('crewmembers')
                .select('crew')
                .eq('crewmember', userId)
                .eq('crew', crewId)
                .maybeSingle()
          : null;

      final afterCrewCheck = DateTime.now();
      debugLog(
        'Crew check completed in ${afterCrewCheck.difference(startTime).inMilliseconds}ms, result=${crewMemberResponse != null}',
      );

      // If user is not part of any crew OR not part of the specified crew, only show their own problems
      if (crewId == null || crewMemberResponse == null) {
        // User is not part of this crew, only show problems they created
        debugLog('User not in crew, loading only their own problems');
        final queryStart = DateTime.now();

        final response = await Supabase.instance.client
            .from('problem')
            .select(_problemSelectFields)
            .eq('event', eventId)
            .eq('originator', userId)
            .order('startdatetime', ascending: false);

        final afterQuery = DateTime.now();
        debugLog(
          'Own problems query completed in ${afterQuery.difference(queryStart).inMilliseconds}ms, count=${response.length}',
        );

        final problems = _parseAndFilterProblems(response);
        final enrichedProblems = await enrichWithSmsReporterNames(problems);

        debugLog(
          'Total loadProblems time (non-crew): ${DateTime.now().difference(startTime).inMilliseconds}ms',
        );
        return enrichedProblems;
      } else {
        // User is part of the crew: show crew's problems + any problems user created for other crews
        debugLog(
          'User is in crew $crewId, loading crew problems + user\'s problems for other crews',
        );
        final queryStart = DateTime.now();

        final response = await Supabase.instance.client
            .from('problem')
            .select(_problemSelectFields)
            .eq('event', eventId)
            .or('crew.eq.$crewId,originator.eq.$userId')
            .order('startdatetime', ascending: false);

        final afterQuery = DateTime.now();
        debugLog(
          'Crew problems query completed in ${afterQuery.difference(queryStart).inMilliseconds}ms, count=${response.length}',
        );

        final problems = _parseAndFilterProblems(response, deduplicate: true);
        final enrichedProblems = await enrichWithSmsReporterNames(problems);

        debugLog(
          'Total loadProblems time (crew member): ${DateTime.now().difference(startTime).inMilliseconds}ms',
        );
        return enrichedProblems;
      }
    } catch (e) {
      debugLogError('Failed to load problems', e);
      throw Exception('Failed to load problems: $e');
    }
  }

  Future<Map<int, List<Map<String, dynamic>>>> loadResponders(
    List<ProblemWithDetails> problems,
  ) async {
    try {
      if (problems.isEmpty) return {};

      final problemIds = problems.map((p) => p.id).toList();
      final response = await Supabase.instance.client
          .from('responders')
          .select(
            'problem, user_id, responded_at, user:user_id(firstname, lastname)',
          )
          .inFilter('problem', problemIds);

      debugLog('loadResponders: Raw response = $response');

      final respondersMap = <int, List<Map<String, dynamic>>>{};
      for (final responder in response) {
        final problemId = responder['problem'] as int;
        if (!respondersMap.containsKey(problemId)) {
          respondersMap[problemId] = [];
        }
        respondersMap[problemId]!.add(responder);
      }

      debugLog('loadResponders: Final map = $respondersMap');
      return respondersMap;
    } catch (e) {
      debugLogError('loadResponders error', e);
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

      final responderName =
          '${userResponse['firstname']} ${userResponse['lastname']}';
      final strip = problemResponse['strip'] as String;
      final crewId = problemResponse['crew'] as int;
      final reporterId = problemResponse['originator'] as String?;

      // Send crew message (fire and forget - don't block UI)
      Supabase.instance.client
          .from('crew_messages')
          .insert({
            'crew': crewId,
            'author': userId,
            'message': '$responderName is on the way',
          })
          .catchError((e) {
            debugLogError(
              'Failed to send crew message (responder was recorded successfully)',
              e,
            );
          });

      // Send notification using Edge Function (fire and forget - don't block UI)
      NotificationService()
          .sendCrewNotification(
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
            includeReporter:
                true, // Include reporter so they know help is coming
            reporterId: reporterId,
          )
          .catchError((e) {
            debugLogError(
              'Failed to send notification (responder was recorded successfully)',
              e,
            );
            return false;
          });

      // Send SMS to reporter if problem was created via SMS (fire and forget - don't block UI)
      // (The send-sms function will check if reporter_phone exists)
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
        const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
        final url = Uri.parse('$supabaseUrl/functions/v1/send-sms');

        http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${session.accessToken}',
                'apikey': supabaseAnonKey,
              },
              body: jsonEncode({
                'problemId': problemId,
                'message': '',
                'type': 'on_my_way',
                'senderName': responderName,
              }),
            )
            .catchError((e) {
              debugLogError(
                'Failed to send SMS to reporter (responder was recorded successfully)',
                e,
              );
              return http.Response('', 500);
            });
      }
    } catch (e) {
      debugLogError('Error updating status (goOnMyWay)', e);
      if (e.toString().contains('duplicate key') ||
          e.toString().contains('UNIQUE')) {
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
      debugLogError('Error loading missing symptom data', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> loadMissingOriginatorData(
    String originatorId,
  ) async {
    try {
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('supabase_id, firstname, lastname')
          .eq('supabase_id', originatorId)
          .maybeSingle();

      return userResponse;
    } catch (e) {
      debugLogError('Error loading missing originator data', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> loadMissingResolverData(
    String actionById,
  ) async {
    try {
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('supabase_id, firstname, lastname')
          .eq('supabase_id', actionById)
          .maybeSingle();

      return userResponse;
    } catch (e) {
      debugLogError('Error loading missing resolver data', e);
      return null;
    }
  }

  /// Load reporter names for problems that have reporter_phone set
  /// Uses the database function get_reporter_name which checks:
  /// 1) users table (app users), 2) sms_reporters table (legacy data)
  Future<Map<String, Map<String, dynamic>>> loadReporterNamesByPhone(
    List<String> phoneNumbers,
  ) async {
    if (phoneNumbers.isEmpty) return {};

    final result = <String, Map<String, dynamic>>{};

    try {
      // TODO: Batch into single RPC call to avoid N+1 queries (requires DB-side changes)
      for (final phone in phoneNumbers) {
        final response = await Supabase.instance.client.rpc(
          'get_reporter_name',
          params: {'reporter_phone': phone},
        );

        if (response != null && response is String && response.isNotEmpty) {
          result[phone] = {'phone': phone, 'name': response};
        }
      }

      return result;
    } catch (e) {
      debugLogError('Failed to load reporter names by phone', e);
      return {};
    }
  }

  /// Enrich problems with SMS reporter data
  Future<List<ProblemWithDetails>> enrichWithSmsReporterNames(
    List<ProblemWithDetails> problems,
  ) async {
    // Collect phone numbers that need lookup
    // Check for reporterPhone and no existing smsReporter or originator data
    final phoneNumbers = problems
        .where(
          (p) =>
              p.problem.reporterPhone != null &&
              p.smsReporter == null &&
              p.originator == null,
        )
        .map((p) => p.problem.reporterPhone!)
        .toSet()
        .toList();

    if (phoneNumbers.isEmpty) return problems;

    final reporters = await loadReporterNamesByPhone(phoneNumbers);
    if (reporters.isEmpty) return problems;

    // Update problems with reporter data
    return problems.map((p) {
      if (p.problem.reporterPhone != null &&
          reporters.containsKey(p.problem.reporterPhone)) {
        return p.copyWith(smsReporter: reporters[p.problem.reporterPhone]);
      }
      return p;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> checkForNewProblems({
    required int eventId,
    required String userId,
    required DateTime since,
    int? crewId,
    bool isSuperUser = false,
  }) async {
    try {
      // Super users viewing a specific crew: only that crew's new problems
      if (isSuperUser && crewId != null) {
        final response = await Supabase.instance.client
            .from('problem')
            .select(_problemSelectFields)
            .eq('event', eventId)
            .eq('crew', crewId)
            .gt('startdatetime', since.toIso8601String())
            .order('startdatetime', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      }

      // Check if user is a crew member
      final crewMemberResponse = crewId != null
          ? await Supabase.instance.client
                .from('crewmembers')
                .select('crew')
                .eq('crewmember', userId)
                .eq('crew', crewId)
                .maybeSingle()
          : null;

      // Non-crew member or no crew: only their own new problems
      if (crewId == null || crewMemberResponse == null) {
        final response = await Supabase.instance.client
            .from('problem')
            .select(_problemSelectFields)
            .eq('event', eventId)
            .eq('originator', userId)
            .gt('startdatetime', since.toIso8601String())
            .order('startdatetime', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      }

      // Crew member: crew's problems + their problems for other crews
      final response = await Supabase.instance.client
          .from('problem')
          .select(_problemSelectFields)
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

      final newMessages = await Supabase.instance.client.rpc(
        'get_new_messages',
        params: {
          'since_time': since.toIso8601String(),
          'problem_ids': problemIdsStr,
        },
      );

      return List<Map<String, dynamic>>.from(newMessages ?? []);
    } catch (e) {
      debugLogError('Error checking for new messages', e);
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

      const updateSelectFields = '''
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
          .select(updateSelectFields)
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
  Future<List<Map<String, dynamic>>> loadMessagesForProblem(
    int problemId,
  ) async {
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select('*')
          .eq('problem', problemId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugLogError('Error loading messages for problem', e);
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
      const resolvedSelectFields = '''
        id,
        enddatetime,
        action,
        actionby,
        action_data:action(id, actionstring),
        actionby_data:actionby(supabase_id, firstname, lastname)
      ''';

      final response = await Supabase.instance.client
          .from('problem')
          .select(resolvedSelectFields)
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

  String getProblemStatus(
    ProblemWithDetails problem,
    Map<int, List<Map<String, dynamic>>> responders,
  ) {
    if (problem.isResolved) return 'resolved';
    if (responders.containsKey(problem.id) &&
        responders[problem.id]!.isNotEmpty) {
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
      await Supabase.instance.client
          .from('problem')
          .update({'symptom': newSymptomId})
          .eq('id', problemId);
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

  /// Check if the current user is a super user.
  Future<bool> checkSuperUserStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;

      final userResponse = await Supabase.instance.client
          .from('users')
          .select('superuser')
          .eq('supabase_id', userId)
          .maybeSingle();

      return userResponse?['superuser'] == true;
    } catch (e) {
      debugLogError('Error checking superuser status', e);
      return false;
    }
  }

  /// Load all crews for an event (for superuser crew selection).
  /// Returns crews sorted: Armorer, Medical, then alphabetically.
  Future<List<Map<String, dynamic>>> loadAllCrewsForEvent(int eventId) async {
    try {
      final response = await Supabase.instance.client
          .from('crews')
          .select('''
            id,
            crewtype:crewtypes(crewtype),
            crew_chief:users(firstname, lastname)
          ''')
          .eq('event', eventId)
          .order('crewtype(crewtype)');

      final crewList = List<Map<String, dynamic>>.from(response);
      crewList.sort((a, b) {
        final aType = (a['crewtype']?['crewtype'] as String?) ?? '';
        final bType = (b['crewtype']?['crewtype'] as String?) ?? '';

        const priorityOrder = ['Armorer', 'Medical'];
        final aIndex = priorityOrder.indexOf(aType);
        final bIndex = priorityOrder.indexOf(bType);

        if (aIndex != -1 && bIndex != -1) {
          return aIndex.compareTo(bIndex);
        } else if (aIndex != -1) {
          return -1;
        } else if (bIndex != -1) {
          return 1;
        } else {
          return aType.compareTo(bType);
        }
      });

      return crewList;
    } catch (e) {
      debugLogError('Error loading all crews', e);
      return [];
    }
  }

  /// Determine if the user is a referee (not a crew member) for the given crew.
  Future<bool> isUserRefereeForCrew(int crewId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return true;

      final crewMemberResponse = await Supabase.instance.client
          .from('crewmembers')
          .select('crew:crew(id, crewtype:crewtypes(crewtype))')
          .eq('crew', crewId)
          .eq('crewmember', userId)
          .maybeSingle();

      return crewMemberResponse == null;
    } catch (e) {
      debugLogError('Error checking crew membership', e);
      return true;
    }
  }

  /// Get the user's crew info for an event.
  /// Returns (crewId, crewName) or (null, null) if user is not in any crew.
  Future<({int? crewId, String? crewName})> getUserCrewInfo(int eventId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return (crewId: null, crewName: null);

      final crewMember = await Supabase.instance.client
          .from('crewmembers')
          .select('''
            crew:crew(
              id,
              event,
              crewtype:crewtypes(crewtype)
            )
          ''')
          .eq('crewmember', userId)
          .eq('crew.event', eventId)
          .maybeSingle();

      if (crewMember != null && crewMember['crew'] != null) {
        final crew = crewMember['crew'] as Map<String, dynamic>;
        final crewTypeData = crew['crewtype'] as Map<String, dynamic>?;
        final crewTypeName = crewTypeData?['crewtype'] as String? ?? 'Crew';
        return (crewId: crew['id'] as int, crewName: crewTypeName);
      }

      return (crewId: null, crewName: null);
    } catch (e) {
      debugLogError('Error getting user crew info', e);
      return (crewId: null, crewName: null);
    }
  }

  /// Get the crew type ID for a given crew.
  Future<int?> getCrewTypeId(int crewId) async {
    try {
      final crewResponse = await Supabase.instance.client
          .from('crews')
          .select('crew_type')
          .eq('id', crewId)
          .maybeSingle();
      return crewResponse?['crew_type'] as int?;
    } catch (e) {
      debugLogError('Error getting crew type ID', e);
      return null;
    }
  }
}
