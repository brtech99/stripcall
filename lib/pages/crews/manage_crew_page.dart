import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'name_finder_dialog.dart';
import '../../models/user.dart' as app_models;
import '../../models/crew_member.dart';
import '../../widgets/settings_menu.dart';
import '../../utils/debug_utils.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';

class ManageCrewPage extends StatefulWidget {
  final String crewId;
  final String eventName;
  final String crewType;

  const ManageCrewPage({
    super.key,
    required this.crewId,
    required this.eventName,
    required this.crewType,
  });

  @override
  State<ManageCrewPage> createState() => _ManageCrewPageState();
}

class _ManageCrewPageState extends State<ManageCrewPage> {
  List<CrewMember> _crewMembers = [];
  bool _isLoading = true;
  String? _error;
  String? _crewChiefName;

  @override
  void initState() {
    super.initState();
    _loadCrewData();
  }

  Future<void> _loadCrewData() async {
    await Future.wait([
      _loadCrewMembers(),
      _loadCrewChief(),
    ]);
  }

  Future<void> _loadCrewChief() async {
    try {
      final response = await Supabase.instance.client
          .from('crews')
          .select('crew_chief:users(firstname, lastname)')
          .eq('id', widget.crewId)
          .single();

      if (mounted && response['crew_chief'] != null) {
        final crewChiefData = response['crew_chief'] as Map<String, dynamic>;
        final firstName = crewChiefData['firstname'] as String? ?? '';
        final lastName = crewChiefData['lastname'] as String? ?? '';
        setState(() {
          _crewChiefName = '${firstName.trim()} ${lastName.trim()}'.trim();
        });
      }
    } catch (e) {
      debugLogError('Error loading crew chief', e);
      setState(() {
        _error = 'Failed to load crew chief: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCrewMembers() async {
    try {
      final crewMemberResponse = await Supabase.instance.client
          .from('crewmembers')
          .select('id, crew, crewmember')
          .eq('crew', widget.crewId);

      if (crewMemberResponse.isEmpty) {
        if (mounted) {
          setState(() {
            _crewMembers = [];
            _isLoading = false;
          });
        }
        return;
      }

      final userIds = crewMemberResponse.map((record) => record['crewmember'] as String).toList();

      final userResponse = await Supabase.instance.client
          .from('users')
          .select('supabase_id, firstname, lastname, phonenbr')
          .inFilter('supabase_id', userIds);

      final userMap = <String, Map<String, dynamic>>{};
      for (final user in userResponse) {
        userMap[user['supabase_id'] as String] = user;
      }

      final combinedData = crewMemberResponse.map((crewMember) {
        final userId = crewMember['crewmember'] as String;
        final userData = userMap[userId];
        return {
          ...crewMember,
          'crewmember': userData,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _crewMembers = combinedData.map<CrewMember>((json) => CrewMember.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLogError('Error loading crew members', e);
      setState(() {
        _error = 'Failed to load crew members: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addCrewMember() async {
    final result = await showDialog<app_models.User>(
      context: context,
      builder: (context) => const NameFinderDialog(title: 'Find Crew Member'),
    );

    if (result != null) {
      try {
        await Supabase.instance.client
            .from('crewmembers')
            .insert({
              'crew': widget.crewId,
              'crewmember': result.supabaseId,
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Crew member added successfully')),
          );
          _loadCrewMembers();
        }
      } catch (e) {
        debugLogError('Error saving crew', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add crew member: $e'),
              backgroundColor: AppColors.statusError,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeCrewMember(String userId) async {
    try {
      await Supabase.instance.client
          .from('crewmembers')
          .delete()
          .eq('crew', widget.crewId)
          .eq('crewmember', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Crew member removed successfully')),
        );
        _loadCrewMembers();
      }
    } catch (e) {
      debugLogError('Error removing crew member', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove crew member: $e'),
            backgroundColor: AppColors.statusError,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.eventName} - ${widget.crewType} Crew'),
        actions: const [
          SettingsMenu(),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('manage_crew_add_member_button'),
        onPressed: _addCrewMember,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.statusError,
              ),
              AppSpacing.verticalMd,
              Text(
                _error!,
                style: AppTypography.bodyMedium(context).copyWith(
                  color: AppColors.statusError,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.verticalLg,
              AppButton(
                onPressed: _loadCrewData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (_crewChiefName != null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Text(
                  'Crew Chief: ',
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _crewChiefName!,
                  style: AppTypography.bodyMedium(context),
                ),
              ],
            ),
          ),
        Expanded(
          child: _crewMembers.isEmpty
              ? const AppEmptyState(
                  icon: Icons.person_add,
                  title: 'No crew members yet',
                  subtitle: 'Tap + to add crew members',
                )
              : ListView.builder(
                  key: const ValueKey('manage_crew_members_list'),
                  padding: AppSpacing.screenPadding,
                  itemCount: _crewMembers.length,
                  itemBuilder: (context, index) {
                    final member = _crewMembers[index];
                    final user = member.user;

                    if (user == null) {
                      return AppCard(
                        margin: EdgeInsets.only(bottom: AppSpacing.sm),
                        child: const AppListTile(
                          title: Text('Unknown User'),
                          subtitle: Text('User data not available'),
                        ),
                      );
                    }

                    return AppCard(
                      key: ValueKey('manage_crew_member_${user.supabaseId}'),
                      margin: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppListTile(
                        title: Text(user.fullName),
                        subtitle: Text(user.phoneNumber ?? 'No phone'),
                        trailing: IconButton(
                          key: ValueKey('manage_crew_remove_${user.supabaseId}'),
                          icon: Icon(
                            Icons.delete,
                            color: AppColors.statusError,
                          ),
                          onPressed: () => _removeCrewMember(user.supabaseId),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
