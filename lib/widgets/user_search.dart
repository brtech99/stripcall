import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as app_models;

class UserSearchField extends StatefulWidget {
  final String label;
  final String? initialValue;
  final void Function(app_models.User) onUserSelected;

  const UserSearchField({
    super.key,
    required this.label,
    this.initialValue,
    required this.onUserSelected,
  });

  @override
  State<UserSearchField> createState() => _UserSearchFieldState();
}

class _UserSearchFieldState extends State<UserSearchField> {
  final TextEditingController _searchController = TextEditingController();
  List<app_models.User> _filteredUsers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialUser();
  }

  Future<void> _loadInitialUser() async {
    if (widget.initialValue == null) return;
    
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('supabase_id, firstname, lastname')
          .eq('supabase_id', widget.initialValue!)
          .single();
      
      if (mounted) {
        final user = app_models.User.fromJson(response);
        _searchController.text = user.lastNameFirstName;
      }
    } catch (e) {
      debugPrint('Error loading initial user: $e');
      if (mounted) {
        _searchController.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _filteredUsers = []);
      return;
    }

    if (query.length < 2) return;

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('supabase_id, firstname, lastname')
          .ilike('lastname', '$query%')
          .order('lastname')
          .limit(10);
      
      if (mounted) {
        setState(() => _filteredUsers = response.map<app_models.User>((json) => app_models.User.fromJson(json)).toList());
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Start typing last name...',
            suffixIcon: _isLoading ? 
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ) : null,
          ),
          onChanged: _searchUsers,
        ),
        if (_filteredUsers.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: Card(
              margin: const EdgeInsets.only(top: 4),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = _filteredUsers[index];
                  return ListTile(
                    dense: true,
                    title: Text(user.lastNameFirstName),
                    onTap: () {
                      _searchController.text = user.lastNameFirstName;
                      widget.onUserSelected(user);
                      setState(() => _filteredUsers = []);
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
} 