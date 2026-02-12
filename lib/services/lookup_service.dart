import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as app_models;
import '../utils/debug_utils.dart';

class LookupService {
  static final LookupService _instance = LookupService._internal();
  factory LookupService() => _instance;
  LookupService._internal();

  List<Map<String, dynamic>> _crewTypes = [];
  List<Map<String, dynamic>> _symptomClasses = [];
  List<Map<String, dynamic>> _symptoms = [];

  List<Map<String, dynamic>> get crewTypes => _crewTypes;
  List<Map<String, dynamic>> get symptomClasses => _symptomClasses;
  List<Map<String, dynamic>> get symptoms => _symptoms;

  Future<void> loadLookupData() async {
    try {
      // Load crew types
      final crewTypes = await Supabase.instance.client
          .from('crewtypes')
          .select()
          .order('crewtype');
      _crewTypes = crewTypes;

      // Load symptom classes
      final symptomClasses = await Supabase.instance.client
          .from('symptomclass')
          .select()
          .order('symptomclassstring');
      _symptomClasses = symptomClasses;

      // Load symptoms
      final symptoms = await Supabase.instance.client
          .from('symptom')
          .select('''
            *,
            symptomclass:symptomclass(symptomclassstring)
          ''')
          .order('symptomstring');
      _symptoms = symptoms;
    } catch (error) {
      throw Exception('Error loading lookup data: $error');
    }
  }

  static Future<List<Map<String, dynamic>>> getCrewTypes() async {
    try {
      final response = await Supabase.instance.client
          .from('crewtypes')
          .select()
          .order('crewtype');
      return response;
    } catch (error) {
      throw Exception('Failed to load crew types: $error');
    }
  }

  static Future<List<app_models.User>> getUsers() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .order('lastname');
      return response
          .map<app_models.User>((json) => app_models.User.fromJson(json))
          .toList();
    } catch (error) {
      throw Exception('Failed to load users: $error');
    }
  }

  /// Fetch symptom classes, optionally filtered by crew type ID.
  /// Falls back to alphabetical order if display_order column is unavailable.
  static Future<List<Map<String, dynamic>>> getSymptomClassesForCrewType(
    int? crewTypeId,
  ) async {
    try {
      var query = Supabase.instance.client
          .from('symptomclass')
          .select('id, symptomclassstring');
      if (crewTypeId != null) {
        query = query.eq('crewType', crewTypeId);
      }
      try {
        return List<Map<String, dynamic>>.from(
          await query.order('display_order', ascending: true),
        );
      } catch (_) {
        // display_order column may not exist — fall back to alphabetical
        var fallback = Supabase.instance.client
            .from('symptomclass')
            .select('id, symptomclassstring');
        if (crewTypeId != null) {
          fallback = fallback.eq('crewType', crewTypeId);
        }
        return List<Map<String, dynamic>>.from(
          await fallback.order('symptomclassstring'),
        );
      }
    } catch (e) {
      debugLogError('Failed to load symptom classes', e);
      rethrow;
    }
  }

  /// Fetch symptoms for a given symptom class.
  /// Falls back to alphabetical order if display_order column is unavailable.
  static Future<List<Map<String, dynamic>>> getSymptomsForClass(
    int symptomClassId,
  ) async {
    try {
      try {
        return List<Map<String, dynamic>>.from(
          await Supabase.instance.client
              .from('symptom')
              .select('id, symptomstring')
              .eq('symptomclass', symptomClassId)
              .order('display_order', ascending: true),
        );
      } catch (_) {
        return List<Map<String, dynamic>>.from(
          await Supabase.instance.client
              .from('symptom')
              .select('id, symptomstring')
              .eq('symptomclass', symptomClassId)
              .order('symptomstring'),
        );
      }
    } catch (e) {
      debugLogError('Failed to load symptoms', e);
      rethrow;
    }
  }

  /// Fetch actions for a given symptom ID with 3-level fallback:
  /// 1. Filtered by symptom, ordered by display_order
  /// 2. Filtered by symptom, ordered alphabetically
  /// 3. All actions ordered alphabetically
  static Future<List<Map<String, dynamic>>> getActionsForSymptom(
    int? symptomId,
  ) async {
    if (symptomId != null) {
      try {
        return List<Map<String, dynamic>>.from(
          await Supabase.instance.client
              .from('action')
              .select('*')
              .eq('symptom', symptomId)
              .order('display_order', ascending: true),
        );
      } catch (_) {
        try {
          return List<Map<String, dynamic>>.from(
            await Supabase.instance.client
                .from('action')
                .select('*')
                .eq('symptom', symptomId)
                .order('actionstring'),
          );
        } catch (_) {
          return List<Map<String, dynamic>>.from(
            await Supabase.instance.client
                .from('action')
                .select('*')
                .order('actionstring'),
          );
        }
      }
    } else {
      return List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('action')
            .select('*')
            .order('display_order', ascending: true),
      );
    }
  }

  /// Fetch strip configuration (numbering scheme and count) for an event.
  static Future<({bool isPodBased, int stripCount})> getStripConfig(
    int eventId,
  ) async {
    final response = await Supabase.instance.client
        .from('events')
        .select('stripnumbering, count')
        .eq('id', eventId)
        .single();
    return (
      isPodBased: response['stripnumbering'] == 'Pods',
      stripCount: (response['count'] as int?) ?? 0,
    );
  }

  /// Look up a crew type ID by name. Returns null if not found.
  static Future<int?> getCrewTypeIdByName(String crewTypeName) async {
    final response = await Supabase.instance.client
        .from('crewtypes')
        .select('id')
        .eq('crewtype', crewTypeName)
        .maybeSingle();
    return response?['id'] as int?;
  }
}
