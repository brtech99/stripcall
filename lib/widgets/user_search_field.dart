import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/theme.dart';
import 'adaptive/adaptive.dart';

class UserSearchField extends StatefulWidget {
  final String label;
  final void Function(Map<String, dynamic> user) onUserSelected;
  final String? initialValue;

  const UserSearchField({
    super.key,
    required this.label,
    required this.onUserSelected,
    this.initialValue,
  });

  @override
  State<UserSearchField> createState() => _UserSearchFieldState();
}

class _UserSearchFieldState extends State<UserSearchField> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _searchUsers(String searchTerm) async {
    final searchTerms = searchTerm.trim().split(' ');
    if (searchTerms.length > 1) {
      final firstName = searchTerms.first;
      final lastName = searchTerms.skip(1).join(' ');
      return await Supabase.instance.client
          .from('users')
          .select()
          .eq('first_name', firstName)
          .eq('last_name', lastName);
    } else {
      return await Supabase.instance.client
          .from('users')
          .select()
          .ilike('last_name', '${searchTerm.trim()}%')
          .order('last_name');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _controller,
                label: widget.label,
                onChanged: (value) {
                  setState(() {
                    _selectedUserId = null;
                    _searchResults = [];
                  });
                },
              ),
            ),
            AppSpacing.horizontalSm,
            AppIconButton(
              icon: const Icon(Icons.search),
              onPressed: _controller.text.trim().isEmpty
                  ? null
                  : () {
                      setState(() {
                        _searchResults = [];
                      });
                      _searchUsers(_controller.text).then((results) {
                        setState(() {
                          _searchResults = results;
                          if (results.length == 1) {
                            _selectedUserId = results.first['id'].toString();
                            _controller.text =
                                '${results.first['first_name']} ${results.first['last_name']}';
                            widget.onUserSelected(results.first);
                          }
                        });
                      });
                    },
            ),
          ],
        ),
        if (_searchResults.length > 1) ...[
          AppSpacing.verticalMd,
          AppDropdown<String>(
            value: _selectedUserId,
            label: 'Select User',
            items: _searchResults.map<DropdownMenuItem<String>>((user) {
              return DropdownMenuItem<String>(
                value: user['id'].toString(),
                child: Text('${user['first_name']} ${user['last_name']}'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedUserId = value;
                final user = _searchResults.firstWhere(
                  (u) => u['id'].toString() == value,
                );
                _controller.text = '${user['first_name']} ${user['last_name']}';
                widget.onUserSelected(user);
              });
            },
          ),
        ],
      ],
    );
  }
}
