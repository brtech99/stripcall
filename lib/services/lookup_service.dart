import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as app_models;

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
      return response.map<app_models.User>((json) => app_models.User.fromJson(json)).toList();
    } catch (error) {
      throw Exception('Failed to load users: $error');
    }
  }
} 