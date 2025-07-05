import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user.dart' as app_models;

class NameFinderDialog extends StatefulWidget {
  final String title;
  
  const NameFinderDialog({
    super.key,
    this.title = 'Find User',
  });

  @override
  State<NameFinderDialog> createState() => _NameFinderDialogState();
}

class _NameFinderDialogState extends State<NameFinderDialog> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  List<app_models.User> _users = [];
  bool _isLoading = false;
  String? _error;
  bool _searchButtonDisabled = false;
  String _lastSearchedFirstName = '';
  String _lastSearchedLastName = '';

  @override
  void initState() {
    super.initState();
    // Add listeners to track text changes
    _firstNameController.addListener(_onTextChanged);
    _lastNameController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final currentFirstName = _firstNameController.text;
    final currentLastName = _lastNameController.text;
    
    // Re-enable search button if text has changed since last search
    if (_searchButtonDisabled && 
        (currentFirstName != _lastSearchedFirstName || currentLastName != _lastSearchedLastName)) {
      setState(() {
        _searchButtonDisabled = false;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_onTextChanged);
    _lastNameController.removeListener(_onTextChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    if (_firstNameController.text.isEmpty && _lastNameController.text.isEmpty) {
      setState(() {
        _users = [];
        _error = 'Please enter at least one name';
        _searchButtonDisabled = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final firstName = _firstNameController.text.isEmpty ? '' : '%${_firstNameController.text}%';
      final lastName = _lastNameController.text.isEmpty ? '' : '%${_lastNameController.text}%';

      final response = await Supabase.instance.client
          .rpc('search_users', params: {
            'first_name_pattern': firstName,
            'last_name_pattern': lastName,
          });

      if (mounted) {
        setState(() {
          _users = response.map<app_models.User>((json) => app_models.User.fromJson(json)).toList();
          _isLoading = false;
          // Disable search button if we found at least one user
          _searchButtonDisabled = _users.isNotEmpty;
          // Store the search terms
          _lastSearchedFirstName = _firstNameController.text;
          _lastSearchedLastName = _lastNameController.text;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to search users: $e';
          _isLoading = false;
          _searchButtonDisabled = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'First Name',
                hintText: 'Enter first name or * for wildcard',
              ),
              onSubmitted: (_) => _searchUsers(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Last Name',
                hintText: 'Enter last name or * for wildcard',
              ),
              onSubmitted: (_) => _searchUsers(),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_users.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return ListTile(
                      title: Text(user.fullName),
                      onTap: () {
                        Navigator.pop(context, user);
                      },
                    );
                  },
                ),
              )
            else if (_firstNameController.text.isNotEmpty || _lastNameController.text.isNotEmpty)
              const Text('No users found'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchButtonDisabled ? null : _searchUsers,
                  child: const Text('Search'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 