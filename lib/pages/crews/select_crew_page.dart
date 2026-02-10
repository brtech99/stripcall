import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'manage_crew_page.dart';
import '../../models/crew.dart';
import '../../models/crew_type.dart';
import '../../models/event.dart';
import '../../widgets/settings_menu.dart';
import '../../utils/auth_helpers.dart';
import '../../utils/debug_utils.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';

class SelectCrewPage extends StatefulWidget {
  const SelectCrewPage({super.key});

  @override
  State<SelectCrewPage> createState() => _SelectCrewPageState();
}

class _SelectCrewPageState extends State<SelectCrewPage> {
  List<Map<String, dynamic>> _crews = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCrews();
  }

  Future<void> _loadCrews() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final isSuperUserRole = await isSuperUser();

      final now = DateTime.now().toIso8601String();

      var query = Supabase.instance.client
          .from('crews')
          .select('''
            *,
            event:events!inner(
              id,
              name,
              startdatetime,
              enddatetime
            ),
            crewtype:crewtypes(
              id,
              crewtype
            )
          ''')
          .gte('event.enddatetime', now);

      if (!isSuperUserRole) {
        query = query.eq('crew_chief', userId);
      }

      final response = await query.order('event(startdatetime)', ascending: true);

      if (mounted) {
        setState(() {
          _crews = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLogError('Error loading crews', e);
      setState(() {
        _error = 'Failed to load crews: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Crews'),
        actions: const [
          SettingsMenu(),
        ],
      ),
      body: _buildBody(),
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
                onPressed: _loadCrews,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_crews.isEmpty) {
      return const AppEmptyState(
        icon: Icons.groups,
        title: 'No crews found',
        subtitle: 'You are not a crew chief for any crews',
      );
    }

    return ListView.builder(
      key: const ValueKey('select_crew_list'),
      padding: AppSpacing.screenPadding,
      itemCount: _crews.length,
      itemBuilder: (context, index) {
        final crewData = _crews[index];
        final crew = Crew.fromJson(crewData);
        final eventData = crewData['event'] as Map<String, dynamic>?;
        final crewTypeData = crewData['crewtype'] as Map<String, dynamic>?;

        if (eventData == null || crewTypeData == null) {
          return AppCard(
            child: AppListTile(
              title: const Text('Invalid Crew Data'),
              subtitle: const Text('Missing event or crew type information'),
            ),
          );
        }

        final event = Event.fromJson(eventData);
        final crewType = CrewType.fromJson(crewTypeData);

        return AppCard(
          key: ValueKey('select_crew_item_${crew.id}'),
          margin: EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppListTile(
            title: Text(event.name),
            subtitle: Text(
              '${crewType.crewType} Crew\n'
              '${event.startDateTime.toLocal().toString().split(' ')[0]} - '
              '${event.endDateTime.toLocal().toString().split(' ')[0]}',
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManageCrewPage(
                    crewId: crew.id.toString(),
                    eventName: event.name,
                    crewType: crewType.crewType,
                  ),
                ),
              ).then((_) => _loadCrews());
            },
          ),
        );
      },
    );
  }
}
