import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user.dart' as app_models;
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';

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
    _firstNameController.addListener(_onTextChanged);
    _lastNameController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final currentFirstName = _firstNameController.text;
    final currentLastName = _lastNameController.text;

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
          _searchButtonDisabled = _users.isNotEmpty;
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
      key: const ValueKey('name_finder_dialog'),
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: AppTypography.titleLarge(context),
            ),
            AppSpacing.verticalMd,
            AppTextField(
              key: const ValueKey('name_finder_firstname_field'),
              controller: _firstNameController,
              label: 'First Name',
              hint: 'Enter first name or * for wildcard',
              onSubmitted: (_) => _searchUsers(),
            ),
            AppSpacing.verticalSm,
            AppTextField(
              key: const ValueKey('name_finder_lastname_field'),
              controller: _lastNameController,
              label: 'Last Name',
              hint: 'Enter last name or * for wildcard',
              onSubmitted: (_) => _searchUsers(),
            ),
            AppSpacing.verticalMd,
            if (_error != null)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  _error!,
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: AppColors.statusError,
                  ),
                ),
              ),
            if (_isLoading)
              const Center(child: AppLoadingIndicator())
            else if (_users.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return AppListTile(
                      title: Text(user.fullName),
                      onTap: () {
                        Navigator.pop(context, user);
                      },
                    );
                  },
                ),
              )
            else if (_firstNameController.text.isNotEmpty || _lastNameController.text.isNotEmpty)
              Text(
                'No users found',
                style: AppTypography.bodyMedium(context),
              ),
            AppSpacing.verticalMd,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton.secondary(
                  key: const ValueKey('name_finder_cancel_button'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                AppSpacing.horizontalSm,
                AppButton(
                  key: const ValueKey('name_finder_search_button'),
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
