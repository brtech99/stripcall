import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/problem_with_details.dart';
import 'notification_service.dart';

class ProblemService {
  static final ProblemService _instance = ProblemService._internal();
  factory ProblemService() => _instance;
  ProblemService._internal();

  Future<List<ProblemWithDetails>> loadProblems({
    required int eventId,
    required String userId,
    int? crewId,
  }) async {
    try {
      final params = <String, dynamic>{
        'event_id': eventId,
        'since_time': DateTime(1970).toIso8601String(),
        'user_id': userId,
      };
      
      if (crewId != null) {
        params['crew_id'] = crewId;
      }
      
      final response = await Supabase.instance.client
          .rpc('get_new_problems_wrapper', params: params);
      
      final problems = <ProblemWithDetails>[];
      if (response != null) {
        for (final json in response) {
          try {
            if (json is Map<String, dynamic>) {
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
            }
          } catch (e) {
            // Error parsing problem
          }
        }
      }
      
      return problems;
    } catch (e) {
      throw Exception('Failed to load problems: $e');
    }
  }

  Future<Map<int, List<Map<String, dynamic>>>> loadResponders(List<ProblemWithDetails> problems) async {
    try {
      if (problems.isEmpty) return {};
      
      final problemIds = problems.map((p) => p.id).toList();
      final response = await Supabase.instance.client
          .from('responders')
          .select('problem, user_id, responded_at')
          .inFilter('problem', problemIds);
      
      final respondersMap = <int, List<Map<String, dynamic>>>{};
      for (final responder in response) {
        final problemId = responder['problem'] as int;
        if (!respondersMap.containsKey(problemId)) {
          respondersMap[problemId] = [];
        }
        respondersMap[problemId]!.add(responder);
      }
      
      return respondersMap;
    } catch (e) {
      return {};
    }
  }

  Future<void> goOnMyWay(int problemId, String userId) async {
    try {
      // Get problem details for notification
      final problemResponse = await Supabase.instance.client
          .from('problem')
          .select('crew, strip')
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
      
      // Send notification using Edge Function
      final responderName = '${userResponse['firstname']} ${userResponse['lastname']}';
      final strip = problemResponse['strip'] as String;
      final crewId = problemResponse['crew'].toString();

      await NotificationService().sendCrewNotification(
        title: 'Crew Member En Route',
        body: '$responderName is en route to Strip $strip',
        crewId: crewId,
        senderId: userId,
        data: {
          'type': 'problem_response',
          'problemId': problemId.toString(),
          'crewId': crewId,
          'strip': strip,
        },
        includeReporter: false, // Don't include responder for "on my way" notifications
      );
    } catch (e) {
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
  }) async {
    try {
      final params = <String, dynamic>{
        'event_id': eventId,
        'since_time': since.toIso8601String(),
        'user_id': userId,
      };
      if (crewId != null) {
        params['crew_id'] = crewId;
      }
      
      final newProblems = await Supabase.instance.client
          .rpc('get_new_problems_wrapper', params: params);
      
      return List<Map<String, dynamic>>.from(newProblems ?? []);
    } catch (e) {
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
      final resolvedProblems = await Supabase.instance.client
          .rpc('get_resolved_problems', params: {
            'event_id': eventId,
            'crew_id': crewId,
            'since_time': since.toIso8601String(),
          });

      return List<Map<String, dynamic>>.from(resolvedProblems ?? []);
    } catch (e) {
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
} 