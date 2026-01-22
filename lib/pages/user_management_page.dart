import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/debug_utils.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _authUsers = [];
  List<Map<String, dynamic>> _publicUsers = [];
  List<Map<String, dynamic>> _pendingUsers = [];
  bool _isLoading = true;
  String? _error;
  String _selectedTable = 'auth_users'; // Now we can access auth users!
  Map<String, dynamic>? _selectedUser;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Debug: Check current user's superuser status
      await _checkCurrentUserStatus();

      print('=== USER MANAGEMENT: Loading all user data via Edge Function ===');

      // Load public and pending users using working Edge Function
      final publicResponse = await Supabase.instance.client.functions.invoke(
        'get-users-data-working',
      );

      if (publicResponse.status != 200) {
        final errorData = publicResponse.data as Map<String, dynamic>?;
        throw Exception(errorData?['error'] ?? 'Failed to load public user data');
      }

      // Load auth users using working auth function
      final authResponse = await Supabase.instance.client.functions.invoke(
        'get-auth-users-working',
      );

      if (authResponse.status != 200) {
        final errorData = authResponse.data as Map<String, dynamic>?;
        throw Exception(errorData?['error'] ?? 'Failed to load auth user data');
      }

      final publicData = publicResponse.data as Map<String, dynamic>;
      final authData = authResponse.data as Map<String, dynamic>;

      final publicUsers = List<Map<String, dynamic>>.from(publicData['publicUsers'] ?? []);
      final pendingUsers = List<Map<String, dynamic>>.from(publicData['pendingUsers'] ?? []);
      final authUsers = List<Map<String, dynamic>>.from(authData['authUsers'] ?? []);

      setState(() {
        _authUsers = authUsers;
        _publicUsers = publicUsers;
        _pendingUsers = pendingUsers;
        _isLoading = false;
      });

      print('=== USER MANAGEMENT: Loaded ${authUsers.length} auth users, ${publicUsers.length} public users, and ${pendingUsers.length} pending users ===');
    } catch (e) {
      debugLogError('Error loading users', e);
      setState(() {
        _error = 'Error loading users: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkCurrentUserStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        print('=== CURRENT USER CHECK: User ID: ${user.id} ===');
        print('=== CURRENT USER CHECK: User Email: ${user.email} ===');

        final userData = await Supabase.instance.client
            .from('users')
            .select('supabase_id, firstname, lastname, superuser, organizer')
            .eq('supabase_id', user.id)
            .single();

        print('=== CURRENT USER CHECK: User Data: $userData ===');
        print('=== CURRENT USER CHECK: Superuser: ${userData['superuser']} ===');
        print('=== CURRENT USER CHECK: Organizer: ${userData['organizer']} ===');
      }
    } catch (e) {
      print('=== CURRENT USER CHECK ERROR: $e ===');
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final searchTerm = _searchController.text.toLowerCase();
    List<Map<String, dynamic>> users;

    switch (_selectedTable) {
      case 'auth_users':
        users = _authUsers.where((user) =>
          user['email']?.toString().toLowerCase().contains(searchTerm) ?? false
        ).toList();
        break;
      case 'public_users':
        users = _publicUsers.where((user) =>
          (user['firstname']?.toString().toLowerCase().contains(searchTerm) ?? false) ||
          (user['lastname']?.toString().toLowerCase().contains(searchTerm) ?? false) ||
          (user['supabase_id']?.toString().toLowerCase().contains(searchTerm) ?? false)
        ).toList();
        break;
      case 'pending_users':
        users = _pendingUsers.where((user) =>
          (user['email']?.toString().toLowerCase().contains(searchTerm) ?? false) ||
          (user['firstname']?.toString().toLowerCase().contains(searchTerm) ?? false) ||
          (user['lastname']?.toString().toLowerCase().contains(searchTerm) ?? false)
        ).toList();
        break;
      default:
        users = [];
    }

    return users;
  }

  void _selectUser(Map<String, dynamic> user) {
    setState(() {
      _selectedUser = Map<String, dynamic>.from(user);
      _isEditing = false;
    });
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _selectedUser = null;
    });
  }

  Future<void> _saveUser() async {
    if (_selectedUser == null) return;

    try {
      switch (_selectedTable) {
        case 'auth_users':
          // Update auth users using Edge Function
          final updateData = {
            'user_id': _selectedUser!['id'],
            'updates': {
              'email': _selectedUser!['email'],
              // Update public.users fields
              'firstname': _selectedUser!['public_user']?['firstname'],
              'lastname': _selectedUser!['public_user']?['lastname'],
              'phonenbr': _selectedUser!['public_user']?['phonenbr'],
              'superuser': _selectedUser!['public_user']?['superuser'],
              'organizer': _selectedUser!['public_user']?['organizer'],
              'is_sms_mode': _selectedUser!['public_user']?['is_sms_mode'],
            }
          };

          final response = await Supabase.instance.client.functions.invoke(
            'update-user',
            body: updateData,
          );

          if (response.status != 200) {
            final errorData = response.data as Map<String, dynamic>?;
            throw Exception(errorData?['error'] ?? 'Failed to update auth user');
          }
          break;
        case 'public_users':
          await Supabase.instance.client
              .from('users')
              .update({
                'firstname': _selectedUser!['firstname'],
                'lastname': _selectedUser!['lastname'],
                'phonenbr': _selectedUser!['phonenbr'],
                'superuser': _selectedUser!['superuser'],
                'organizer': _selectedUser!['organizer'],
                'is_sms_mode': _selectedUser!['is_sms_mode'],
              })
              .eq('supabase_id', _selectedUser!['supabase_id']);
          break;
        case 'pending_users':
          await Supabase.instance.client
              .from('pending_users')
              .update({
                'firstname': _selectedUser!['firstname'],
                'lastname': _selectedUser!['lastname'],
                'phone_number': _selectedUser!['phone_number'],
              })
              .eq('email', _selectedUser!['email']);
          break;
      }

      await _loadUsers();
      setState(() {
        _isEditing = false;
        _selectedUser = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated successfully')),
      );
    } catch (e) {
      debugLogError('Error updating user', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating user: $e')),
      );
    }
  }

  Future<void> _deleteUser() async {
    if (_selectedUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this user? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      print('=== DELETE USER: Starting deletion process ===');
      print('=== DELETE USER: Selected table: $_selectedTable ===');
      print('=== DELETE USER: Selected user: $_selectedUser ===');

      switch (_selectedTable) {
        case 'auth_users':
          // Delete from auth.users using Edge Function
          print('=== DELETE USER: Attempting to delete auth user with ID: ${_selectedUser!['id']} ===');

          final response = await Supabase.instance.client.functions.invoke(
            'delete-user',
            body: {'user_id': _selectedUser!['id']},
          );

          print('=== DELETE USER: Response status: ${response.status} ===');
          print('=== DELETE USER: Response data: ${response.data} ===');

          if (response.status != 200) {
            final errorData = response.data as Map<String, dynamic>?;
            print('=== DELETE USER: Error response: $errorData ===');
            throw Exception(errorData?['error'] ?? 'Failed to delete user');
          }

          print('=== DELETE USER: Auth user deletion successful ===');
          break;
        case 'public_users':
          await Supabase.instance.client
              .from('users')
              .delete()
              .eq('supabase_id', _selectedUser!['supabase_id']);
          break;
        case 'pending_users':
          await Supabase.instance.client
              .from('pending_users')
              .delete()
              .eq('email', _selectedUser!['email']);
          break;
      }

      await _loadUsers();
      setState(() {
        _selectedUser = null;
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted successfully')),
      );
    } catch (e) {
      print('=== DELETE USER: Exception caught ===');
      print('=== DELETE USER: Exception type: ${e.runtimeType} ===');
      print('=== DELETE USER: Exception message: $e ===');
      debugLogError('Error deleting user', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting user: $e')),
      );
    }
  }

  Future<void> _addUser() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddUserDialog(tableType: _selectedTable),
    );

    if (result != null) {
      try {
        switch (_selectedTable) {
          case 'auth_users':
            // Auth user was created via edge function in the dialog
            // result will be {'success': true} if successful
            if (result['success'] == true) {
              await _loadUsers();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User created successfully')),
              );
            }
            return;
          case 'public_users':
            await Supabase.instance.client
                .from('users')
                .insert(result);
            break;
          case 'pending_users':
            await Supabase.instance.client
                .from('pending_users')
                .insert(result);
            break;
        }

        await _loadUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User added successfully')),
        );
      } catch (e) {
        debugLogError('Error adding user', e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding user: $e')),
        );
      }
    }
  }

  Widget _buildUserList() {
    final users = _filteredUsers;

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isSelected = _selectedUser != null &&
            _getUserKey(user) == _getUserKey(_selectedUser!);

        return Card(
          color: isSelected ? Colors.blue.shade50 : null,
          child: ListTile(
            title: _buildUserTitle(user),
            subtitle: _buildUserSubtitle(user),
            trailing: _buildUserTrailing(user),
            onTap: () => _selectUser(user),
          ),
        );
      },
    );
  }

  String _getUserKey(Map<String, dynamic> user) {
    switch (_selectedTable) {
      case 'auth_users':
        return user['id'] ?? '';
      case 'public_users':
        return user['supabase_id'] ?? '';
      case 'pending_users':
        return user['email'] ?? '';
      default:
        return '';
    }
  }

  Widget _buildUserTitle(Map<String, dynamic> user) {
    switch (_selectedTable) {
      case 'auth_users':
        return Text(user['email'] ?? 'No email');
      case 'public_users':
        final firstName = user['firstname'] ?? '';
        final lastName = user['lastname'] ?? '';
        return Text('$firstName $lastName'.trim().isEmpty ? 'No name' : '$firstName $lastName');
      case 'pending_users':
        final firstName = user['firstname'] ?? '';
        final lastName = user['lastname'] ?? '';
        return Text('$firstName $lastName'.trim().isEmpty ? 'No name' : '$firstName $lastName');
      default:
        return const Text('Unknown');
    }
  }

  Widget _buildUserSubtitle(Map<String, dynamic> user) {
    switch (_selectedTable) {
      case 'auth_users':
        final confirmed = user['email_confirmed_at'] != null;
        return Text('${user['email']} - ${confirmed ? 'Confirmed' : 'Not confirmed'}');
      case 'public_users':
        final roles = <String>[];
        if (user['superuser'] == true) roles.add('Super User');
        if (user['organizer'] == true) roles.add('Organizer');
        return Text('${user['phonenbr'] ?? 'No phone'} - ${roles.isEmpty ? 'User' : roles.join(', ')}');
      case 'pending_users':
        return Text('${user['email']} - ${user['phone_number'] ?? 'No phone'}');
      default:
        return const Text('');
    }
  }

  Widget _buildUserTrailing(Map<String, dynamic> user) {
    final confirmed = user['email_confirmed_at'] != null;

    switch (_selectedTable) {
      case 'auth_users':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (confirmed)
              const Icon(Icons.verified, color: Colors.green, size: 16)
            else
              const Icon(Icons.pending, color: Colors.orange, size: 16),
            const SizedBox(width: 8),
            Text(user['id']?.toString().substring(0, 8) ?? ''),
          ],
        );
      case 'public_users':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user['superuser'] == true)
              const Icon(Icons.admin_panel_settings, color: Colors.red, size: 16),
            if (user['organizer'] == true)
              const Icon(Icons.event, color: Colors.blue, size: 16),
            const SizedBox(width: 8),
            Text(user['supabase_id']?.toString().substring(0, 8) ?? ''),
          ],
        );
      case 'pending_users':
        return Text(user['email'] ?? '');
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildUserDetails() {
    if (_selectedUser == null) {
      return const Center(
        child: Text('Select a user to view details'),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'User Details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Row(
                  children: [
                    if (!_isEditing) ...[
                      IconButton(
                        onPressed: _startEditing,
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        onPressed: _deleteUser,
                        icon: const Icon(Icons.delete),
                        tooltip: 'Delete',
                        color: Colors.red,
                      ),
                    ] else ...[
                      IconButton(
                        onPressed: _saveUser,
                        icon: const Icon(Icons.save),
                        tooltip: 'Save',
                        color: Colors.green,
                      ),
                      IconButton(
                        onPressed: _cancelEditing,
                        icon: const Icon(Icons.cancel),
                        tooltip: 'Cancel',
                        color: Colors.orange,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildUserDetailFields(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDetailFields() {
    if (_selectedUser == null) return const SizedBox.shrink();

    final fields = <Widget>[];

    switch (_selectedTable) {
      case 'auth_users':
        fields.addAll([
          _buildDetailField('ID', _selectedUser!['id'], isEditing: false),
          _buildDetailField('Email', _selectedUser!['email'], isEditing: _isEditing),
          _buildDetailField('First Name', _selectedUser!['public_user']?['firstname'] ?? '', isEditing: _isEditing),
          _buildDetailField('Last Name', _selectedUser!['public_user']?['lastname'] ?? '', isEditing: _isEditing),
          _buildDetailField('Phone', _selectedUser!['public_user']?['phonenbr'] ?? '', isEditing: _isEditing),
          _buildDetailField('Super User', _selectedUser!['public_user']?['superuser']?.toString() ?? 'false', isEditing: _isEditing, isBoolean: true),
          _buildDetailField('Organizer', _selectedUser!['public_user']?['organizer']?.toString() ?? 'false', isEditing: _isEditing, isBoolean: true),
          _buildDetailField('SMS Mode', _selectedUser!['public_user']?['is_sms_mode']?.toString() ?? 'false', isEditing: _isEditing, isBoolean: true),
          _buildDetailField('Confirmed At', _selectedUser!['email_confirmed_at']?.toString() ?? 'Not confirmed', isEditing: false),
          _buildDetailField('Created At', _selectedUser!['created_at']?.toString() ?? '', isEditing: false),
        ]);
        break;
      case 'public_users':
        fields.addAll([
          _buildDetailField('Supabase ID', _selectedUser!['supabase_id'], isEditing: false),
          _buildDetailField('First Name', _selectedUser!['firstname'], isEditing: _isEditing),
          _buildDetailField('Last Name', _selectedUser!['lastname'], isEditing: _isEditing),
          _buildDetailField('Phone', _selectedUser!['phonenbr'], isEditing: _isEditing),
          _buildDetailField('Super User', _selectedUser!['superuser']?.toString() ?? 'false', isEditing: _isEditing, isBoolean: true),
          _buildDetailField('Organizer', _selectedUser!['organizer']?.toString() ?? 'false', isEditing: _isEditing, isBoolean: true),
          _buildDetailField('SMS Mode', _selectedUser!['is_sms_mode']?.toString() ?? 'false', isEditing: _isEditing, isBoolean: true),
        ]);
        break;
      case 'pending_users':
        fields.addAll([
          _buildDetailField('Email', _selectedUser!['email'], isEditing: false),
          _buildDetailField('First Name', _selectedUser!['firstname'], isEditing: _isEditing),
          _buildDetailField('Last Name', _selectedUser!['lastname'], isEditing: _isEditing),
          _buildDetailField('Phone', _selectedUser!['phone_number'], isEditing: _isEditing),
          _buildDetailField('Created At', _selectedUser!['created_at']?.toString() ?? '', isEditing: false),
        ]);
        break;
    }

    return Column(children: fields);
  }

  // Map display labels to actual database field names
  String _labelToFieldName(String label) {
    switch (label) {
      case 'Super User':
        return 'superuser';
      case 'SMS Mode':
        return 'is_sms_mode';
      case 'First Name':
        return 'firstname';
      case 'Last Name':
        return 'lastname';
      case 'Phone':
        return 'phonenbr';
      default:
        return label.toLowerCase().replaceAll(' ', '_');
    }
  }

  Widget _buildDetailField(String label, String value, {bool isEditing = false, bool isBoolean = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isEditing && isBoolean
                ? Checkbox(
                    value: value.toLowerCase() == 'true',
                    onChanged: (checked) {
                      setState(() {
                        final fieldName = _labelToFieldName(label);
                        // Handle nested public_user fields for auth users
                        if (_selectedTable == 'auth_users') {
                          if (_selectedUser!['public_user'] == null) {
                            _selectedUser!['public_user'] = {};
                          }
                          _selectedUser!['public_user'][fieldName] = checked;
                        } else {
                          _selectedUser![fieldName] = checked;
                        }
                      });
                    },
                  )
                : isEditing
                    ? TextFormField(
                        initialValue: value,
                        onChanged: (newValue) {
                          setState(() {
                            final fieldName = _labelToFieldName(label);
                            // Handle nested public_user fields for auth users
                            if (_selectedTable == 'auth_users') {
                              if (label == 'Email') {
                                // Email is stored directly on the auth user, not in public_user
                                _selectedUser!['email'] = newValue;
                              } else {
                                if (_selectedUser!['public_user'] == null) {
                                  _selectedUser!['public_user'] = {};
                                }
                                _selectedUser!['public_user'][fieldName] = newValue;
                              }
                            } else {
                              _selectedUser![fieldName] = newValue;
                            }
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      )
                    : Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      ElevatedButton(
                        onPressed: _loadUsers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    // Left panel - Table selector and user list
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          // Table selector
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment(value: 'auth_users', label: Text('Auth Users')),
                                      ButtonSegment(value: 'public_users', label: Text('Public Users')),
                                      ButtonSegment(value: 'pending_users', label: Text('Pending Users')),
                                    ],
                                    selected: {_selectedTable},
                                    onSelectionChanged: (Set<String> selection) {
                                      setState(() {
                                        _selectedTable = selection.first;
                                        _selectedUser = null;
                                        _isEditing = false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: _addUser,
                                  icon: const Icon(Icons.add),
                                  tooltip: 'Add User',
                                ),
                              ],
                            ),
                          ),
                          // Search field
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search users...',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          // User count
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              '${_filteredUsers.length} users found',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // User list
                          Expanded(child: _buildUserList()),
                        ],
                      ),
                    ),
                    // Right panel - User details
                    Expanded(
                      flex: 1,
                      child: _buildUserDetails(),
                    ),
                  ],
                ),
    );
  }
}

class AddUserDialog extends StatefulWidget {
  final String tableType;

  const AddUserDialog({super.key, required this.tableType});

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabaseIdController = TextEditingController();
  bool _isSuperUser = false;
  bool _isOrganizer = false;
  bool _isSmsMode = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _supabaseIdController.dispose();
    super.dispose();
  }

  Future<void> _createAuthUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create-user',
        body: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'firstname': _firstNameController.text.trim(),
          'lastname': _lastNameController.text.trim(),
          'phonenbr': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          'superuser': _isSuperUser,
          'is_sms_mode': _isSmsMode,
          'skip_email_confirmation': true,
        },
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        throw Exception(errorData?['error'] ?? 'Failed to create user');
      }

      Navigator.of(context).pop({'success': true});
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${widget.tableType.replaceAll('_', ' ').toUpperCase()}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.tableType == 'auth_users') ...[
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email *'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password *'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name *'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter first name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name *'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter last name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Super User'),
                  value: _isSuperUser,
                  onChanged: (value) {
                    setState(() {
                      _isSuperUser = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('SMS Mode'),
                  subtitle: const Text('Receive messages via SMS'),
                  value: _isSmsMode,
                  onChanged: (value) {
                    setState(() {
                      _isSmsMode = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              if (widget.tableType == 'public_users') ...[
                TextFormField(
                  controller: _supabaseIdController,
                  decoration: const InputDecoration(labelText: 'Supabase ID *'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter Supabase ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (widget.tableType == 'public_users' || widget.tableType == 'pending_users') ...[
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name *'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter first name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name *'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter last name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (widget.tableType == 'pending_users') ...[
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email *'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (widget.tableType == 'public_users' || widget.tableType == 'pending_users') ...[
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.tableType == 'public_users') ...[
                CheckboxListTile(
                  title: const Text('Super User'),
                  value: _isSuperUser,
                  onChanged: (value) {
                    setState(() {
                      _isSuperUser = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Organizer'),
                  value: _isOrganizer,
                  onChanged: (value) {
                    setState(() {
                      _isOrganizer = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () {
                  if (widget.tableType == 'auth_users') {
                    _createAuthUser();
                  } else if (_formKey.currentState!.validate()) {
                    Map<String, dynamic> userData = {};

                    switch (widget.tableType) {
                      case 'public_users':
                        userData = {
                          'supabase_id': _supabaseIdController.text,
                          'firstname': _firstNameController.text,
                          'lastname': _lastNameController.text,
                          'phonenbr': _phoneController.text,
                          'superuser': _isSuperUser,
                          'organizer': _isOrganizer,
                        };
                        break;
                      case 'pending_users':
                        userData = {
                          'email': _emailController.text,
                          'firstname': _firstNameController.text,
                          'lastname': _lastNameController.text,
                          'phone_number': _phoneController.text,
                        };
                        break;
                    }

                    Navigator.of(context).pop(userData);
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
