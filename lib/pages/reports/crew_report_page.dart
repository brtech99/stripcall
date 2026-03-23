import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/event.dart';
import '../../models/problem_with_details.dart';
import '../../services/supabase_manager.dart';
import '../../utils/auth_helpers.dart';
import '../../utils/debug_utils.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive/adaptive.dart';

import 'report_download_stub.dart'
    if (dart.library.js_interop) 'report_download_web.dart'
    as download;

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

abstract class CrewReportRepository {
  String? get currentUserId;
  Future<bool> checkIsSuperUser();
  Future<List<Event>> fetchAllEvents({required bool isSuperUser, required String userId});
  Future<List<Map<String, dynamic>>> fetchCrewsForEvent(int eventId, {required bool isSuperUser, required String userId});
  Future<List<ProblemWithDetails>> fetchProblems(int eventId, int crewId);
}

class DefaultCrewReportRepository implements CrewReportRepository {
  @override
  String? get currentUserId => SupabaseManager().auth.currentUser?.id;

  @override
  Future<bool> checkIsSuperUser() => isSuperUser();

  @override
  Future<List<Event>> fetchAllEvents({required bool isSuperUser, required String userId}) async {
    if (isSuperUser) {
      final response = await SupabaseManager()
          .from('events')
          .select()
          .order('startdatetime', ascending: false);
      return response.map<Event>((json) => Event.fromJson(json)).toList();
    }
    // Crew chief: events where they are crew_chief
    final response = await SupabaseManager()
        .from('crews')
        .select('event:events!inner(*)')
        .eq('crew_chief', userId);
    final events = <Event>[];
    final seenIds = <int>{};
    for (final row in response) {
      final eventData = row['event'] as Map<String, dynamic>?;
      if (eventData != null) {
        final event = Event.fromJson(eventData);
        if (seenIds.add(event.id)) {
          events.add(event);
        }
      }
    }
    events.sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
    return events;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCrewsForEvent(
    int eventId, {
    required bool isSuperUser,
    required String userId,
  }) async {
    var query = SupabaseManager()
        .from('crews')
        .select('id, crewtype:crewtypes(crewtype)');
    query = query.eq('event', eventId);
    if (!isSuperUser) {
      query = query.eq('crew_chief', userId);
    }
    return await query;
  }

  @override
  Future<List<ProblemWithDetails>> fetchProblems(int eventId, int crewId) async {
    final response = await SupabaseManager()
        .from('problem')
        .select('''
          id, event, crew, originator, strip, symptom, startdatetime, action, actionby, enddatetime, notes, reporter_phone,
          symptom_data:symptom(id, symptomstring),
          action_data:action(id, actionstring),
          originator_data:originator(supabase_id, firstname, lastname),
          actionby_data:actionby(supabase_id, firstname, lastname)
        ''')
        .eq('event', eventId)
        .eq('crew', crewId)
        .order('startdatetime', ascending: true);
    return response.map<ProblemWithDetails>((json) => ProblemWithDetails.fromJson(json)).toList();
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class CrewReportPage extends StatefulWidget {
  final CrewReportRepository? repository;
  const CrewReportPage({super.key, this.repository});

  @override
  State<CrewReportPage> createState() => _CrewReportPageState();
}

class _CrewReportPageState extends State<CrewReportPage> {
  late final CrewReportRepository _repo;
  bool _isLoadingInit = true;
  bool _isLoadingReport = false;
  bool _isSuperUser = false;
  String? _error;

  List<Event> _events = [];
  List<Map<String, dynamic>> _crews = [];
  Event? _selectedEvent;
  Map<String, dynamic>? _selectedCrew;

  // Report data
  List<ProblemWithDetails> _problems = [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DefaultCrewReportRepository();
    _loadInit();
  }

  Future<void> _loadInit() async {
    try {
      final userId = _repo.currentUserId;
      if (userId == null) throw Exception('Not logged in');
      final su = await _repo.checkIsSuperUser();
      final events = await _repo.fetchAllEvents(isSuperUser: su, userId: userId);
      if (!mounted) return;
      setState(() {
        _isSuperUser = su;
        _events = events;
        _isLoadingInit = false;
      });
    } catch (e) {
      debugLogError('Error loading report init', e);
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load: $e';
        _isLoadingInit = false;
      });
    }
  }

  Future<void> _onEventSelected(Event event) async {
    setState(() {
      _selectedEvent = event;
      _selectedCrew = null;
      _problems = [];
      _crews = [];
    });
    try {
      final userId = _repo.currentUserId!;
      final crews = await _repo.fetchCrewsForEvent(
        event.id,
        isSuperUser: _isSuperUser,
        userId: userId,
      );
      if (!mounted) return;
      setState(() => _crews = crews);
    } catch (e) {
      debugLogError('Error loading crews', e);
    }
  }

  Future<void> _onCrewSelected(Map<String, dynamic> crew) async {
    setState(() {
      _selectedCrew = crew;
      _isLoadingReport = true;
      _problems = [];
    });
    try {
      final problems = await _repo.fetchProblems(
        _selectedEvent!.id,
        crew['id'] as int,
      );
      if (!mounted) return;
      setState(() {
        _problems = problems;
        _isLoadingReport = false;
      });
    } catch (e) {
      debugLogError('Error loading report', e);
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load report: $e';
        _isLoadingReport = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Computed report data
  // ---------------------------------------------------------------------------

  int get _totalProblems => _problems.length;

  Map<String, int> get _problemsPerDay {
    final map = <String, int>{};
    for (final p in _problems) {
      final d = p.startDateTime.toLocal();
      final key = '${_monthAbbr[d.month]} ${d.day}';
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  List<MapEntry<String, int>> get _symptomCounts {
    final map = <String, int>{};
    for (final p in _problems) {
      final s = p.symptomString ?? 'Unknown';
      map[s] = (map[s] ?? 0) + 1;
    }
    final list = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  String get _avgResolveTime {
    final resolved = _problems.where((p) => p.endDateTime != null).toList();
    if (resolved.isEmpty) return 'N/A';
    final totalMinutes = resolved.fold<int>(
      0,
      (sum, p) => sum + p.endDateTime!.difference(p.startDateTime).inMinutes,
    );
    final avg = totalMinutes ~/ resolved.length;
    if (avg < 60) return '$avg min';
    return '${avg ~/ 60}h ${avg % 60}m';
  }

  static const _monthAbbr = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $ampm';
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${_monthAbbr[local.month]} ${local.day}, ${_formatTime(dt)}';
  }

  String _resolveTime(ProblemWithDetails p) {
    if (p.endDateTime == null) return 'Open';
    final mins = p.endDateTime!.difference(p.startDateTime).inMinutes;
    if (mins < 60) return '$mins min';
    return '${mins ~/ 60}h ${mins % 60}m';
  }

  // ---------------------------------------------------------------------------
  // CSV / Share
  // ---------------------------------------------------------------------------

  String _generateCsv() {
    final crewType = _selectedCrew?['crewtype']?['crewtype'] ?? 'Unknown';
    final buf = StringBuffer();

    buf.writeln('Crew Report: ${_selectedEvent!.name} - $crewType');
    buf.writeln('Generated: ${DateTime.now().toLocal()}');
    buf.writeln();
    buf.writeln('Total Problems,$_totalProblems');
    buf.writeln('Average Time to Resolve,$_avgResolveTime');
    buf.writeln();

    buf.writeln('Problems Per Day');
    for (final entry in _problemsPerDay.entries) {
      buf.writeln('${entry.key},${entry.value}');
    }
    buf.writeln();

    buf.writeln('Symptoms by Frequency');
    buf.writeln('Symptom,Count');
    for (final entry in _symptomCounts) {
      buf.writeln('"${entry.key}",${entry.value}');
    }
    buf.writeln();

    buf.writeln('Problem Detail');
    buf.writeln('Time,Strip,Symptom,Action Taken,Time to Resolve');
    for (final p in _problems) {
      buf.writeln('"${_formatDateTime(p.startDateTime)}","${p.strip}","${p.symptomString ?? ''}","${p.actionString ?? ''}","${_resolveTime(p)}"');
    }
    return buf.toString();
  }

  Future<void> _shareReport() async {
    final csv = _generateCsv();
    final crewType = _selectedCrew?['crewtype']?['crewtype'] ?? 'Crew';
    final fileName = 'crew_report_${_selectedEvent!.name}_$crewType.csv'
        .replaceAll(' ', '_')
        .toLowerCase();

    if (kIsWeb) {
      download.downloadCsvFile(csv, fileName);
    } else {
      await SharePlus.instance.share(
        ShareParams(text: csv, subject: 'Crew Report - ${_selectedEvent!.name} - $crewType'),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);

    final exportIcon = kIsWeb ? Icons.download : (isApple ? CupertinoIcons.share : Icons.share);
    final exportTooltip = kIsWeb ? 'Download CSV' : 'Share';

    if (isApple) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Crew Report'),
          trailing: _problems.isNotEmpty
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _shareReport,
                  child: Icon(kIsWeb ? CupertinoIcons.arrow_down_doc : CupertinoIcons.share, size: 22),
                )
              : null,
        ),
        child: SafeArea(child: _buildBody(context)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crew Report'),
        actions: [
          if (_problems.isNotEmpty)
            IconButton(
              key: const ValueKey('report_share_button'),
              icon: Icon(exportIcon),
              tooltip: exportTooltip,
              onPressed: _shareReport,
            ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoadingInit) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_error != null && _events.isEmpty) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.statusError),
              AppSpacing.verticalMd,
              Text(_error!, style: AppTypography.bodyMedium(context).copyWith(color: AppColors.statusError)),
              AppSpacing.verticalLg,
              AppButton(onPressed: _loadInit, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(AppSpacing.md),
      children: [
        _buildEventPicker(context),
        if (_selectedEvent != null) ...[
          SizedBox(height: AppSpacing.md),
          _buildCrewPicker(context),
        ],
        if (_isLoadingReport) ...[
          SizedBox(height: AppSpacing.xl),
          const Center(child: AppLoadingIndicator()),
        ],
        if (_problems.isNotEmpty) ...[
          SizedBox(height: AppSpacing.lg),
          if (kIsWeb)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: AppButton(
                  onPressed: _shareReport,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.download, size: 18),
                      SizedBox(width: AppSpacing.sm),
                      const Text('Download CSV'),
                    ],
                  ),
                ),
              ),
            ),
          _buildSummaryCards(context),
          SizedBox(height: AppSpacing.lg),
          _buildProblemsPerDay(context),
          SizedBox(height: AppSpacing.lg),
          _buildSymptomCounts(context),
          SizedBox(height: AppSpacing.lg),
          _buildDetailTable(context),
          SizedBox(height: AppSpacing.xl),
        ],
        if (!_isLoadingReport && _selectedCrew != null && _problems.isEmpty) ...[
          SizedBox(height: AppSpacing.xl),
          const AppEmptyState(
            icon: Icons.assessment_outlined,
            title: 'No problems',
            subtitle: 'No problems recorded for this crew at this event',
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Pickers
  // ---------------------------------------------------------------------------

  Widget _buildEventPicker(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);

    if (isApple) {
      return _buildIosPicker(
        context,
        label: 'Event',
        value: _selectedEvent?.name ?? 'Select an event',
        hasValue: _selectedEvent != null,
        onTap: () => _showEventPicker(context),
      );
    }

    return DropdownButtonFormField<int>(
      key: const ValueKey('report_event_dropdown'),
      decoration: const InputDecoration(labelText: 'Event'),
      value: _selectedEvent?.id,
      items: _events.map((e) {
        final d = e.startDateTime;
        final label = '${e.name} (${_monthAbbr[d.month]} ${d.day}, ${d.year})';
        return DropdownMenuItem(value: e.id, child: Text(label));
      }).toList(),
      onChanged: (id) {
        if (id != null) {
          final event = _events.firstWhere((e) => e.id == id);
          _onEventSelected(event);
        }
      },
    );
  }

  Widget _buildCrewPicker(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);

    if (_crews.isEmpty) {
      return Text(
        'No crews found for this event',
        style: AppTypography.bodyMedium(context).copyWith(color: AppColors.textSecondary(context)),
      );
    }

    if (isApple) {
      final crewType = _selectedCrew?['crewtype']?['crewtype'] as String?;
      return _buildIosPicker(
        context,
        label: 'Crew',
        value: crewType ?? 'Select a crew',
        hasValue: _selectedCrew != null,
        onTap: () => _showCrewPicker(context),
      );
    }

    return DropdownButtonFormField<int>(
      key: const ValueKey('report_crew_dropdown'),
      decoration: const InputDecoration(labelText: 'Crew'),
      value: _selectedCrew?['id'] as int?,
      items: _crews.map((c) {
        final type = c['crewtype']?['crewtype'] as String? ?? 'Unknown';
        return DropdownMenuItem(value: c['id'] as int, child: Text(type));
      }).toList(),
      onChanged: (id) {
        if (id != null) {
          final crew = _crews.firstWhere((c) => c['id'] == id);
          _onCrewSelected(crew);
        }
      },
    );
  }

  Widget _buildIosPicker(
    BuildContext context, {
    required String label,
    required String value,
    required bool hasValue,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.iosSurfaceDark : AppColors.iosSurface,
          borderRadius: AppSpacing.borderRadiusLg,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.labelSmall(context).copyWith(color: AppColors.textSecondary(context))),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: AppTypography.bodyLarge(context).copyWith(
                      color: hasValue ? AppColors.textPrimary(context) : AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_down, size: 16, color: AppColors.textSecondary(context)),
          ],
        ),
      ),
    );
  }

  void _showEventPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _events.length,
                itemBuilder: (ctx, i) {
                  final e = _events[i];
                  final d = e.startDateTime;
                  final label = '${e.name} (${_monthAbbr[d.month]} ${d.day}, ${d.year})';
                  final selected = _selectedEvent?.id == e.id;
                  return CupertinoListTile(
                    title: Text(label),
                    trailing: selected ? const Icon(CupertinoIcons.checkmark, color: CupertinoColors.activeBlue) : null,
                    onTap: () {
                      _onEventSelected(e);
                      Navigator.of(ctx).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCrewPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _crews.length,
                itemBuilder: (ctx, i) {
                  final c = _crews[i];
                  final type = c['crewtype']?['crewtype'] as String? ?? 'Unknown';
                  final selected = _selectedCrew?['id'] == c['id'];
                  return CupertinoListTile(
                    title: Text(type),
                    trailing: selected ? const Icon(CupertinoIcons.checkmark, color: CupertinoColors.activeBlue) : null,
                    onTap: () {
                      _onCrewSelected(c);
                      Navigator.of(ctx).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Report sections
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCards(BuildContext context) {
    final resolved = _problems.where((p) => p.endDateTime != null).length;
    return Row(
      children: [
        Expanded(child: _buildStatCard(context, 'Total', '$_totalProblems')),
        SizedBox(width: AppSpacing.sm),
        Expanded(child: _buildStatCard(context, 'Resolved', '$resolved')),
        SizedBox(width: AppSpacing.sm),
        Expanded(child: _buildStatCard(context, 'Avg Resolve', _avgResolveTime)),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value) {
    final isApple = AppTheme.isApplePlatform(context);
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isApple
            ? (isDark ? AppColors.iosSurfaceDark : AppColors.iosSurface)
            : AppColors.surfaceContainerHigh(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.headlineSmall(context).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.labelSmall(context).copyWith(color: AppColors.textSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemsPerDay(BuildContext context) {
    final days = _problemsPerDay;
    return _buildSection(
      context,
      title: 'Problems Per Day',
      child: Column(
        children: days.entries.map((entry) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.key, style: AppTypography.bodyMedium(context)),
                Text(
                  '${entry.value}',
                  style: AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSymptomCounts(BuildContext context) {
    final symptoms = _symptomCounts;
    return _buildSection(
      context,
      title: 'Symptoms by Frequency',
      child: Column(
        children: symptoms.map((entry) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(entry.key, style: AppTypography.bodyMedium(context))),
                Text(
                  '${entry.value}',
                  style: AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailTable(BuildContext context) {
    return _buildSection(
      context,
      title: 'Problem Detail',
      child: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Time', style: AppTypography.labelSmall(context).copyWith(fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Strip', style: AppTypography.labelSmall(context).copyWith(fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('Symptom', style: AppTypography.labelSmall(context).copyWith(fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('Action', style: AppTypography.labelSmall(context).copyWith(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Resolve', style: AppTypography.labelSmall(context).copyWith(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          ...(_problems.map((p) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: Text(_formatDateTime(p.startDateTime), style: AppTypography.bodySmall(context))),
                  Expanded(flex: 1, child: Text(p.strip, style: AppTypography.bodySmall(context))),
                  Expanded(flex: 3, child: Text(p.symptomString ?? '', style: AppTypography.bodySmall(context))),
                  Expanded(flex: 3, child: Text(p.actionString ?? '', style: AppTypography.bodySmall(context))),
                  Expanded(flex: 2, child: Text(_resolveTime(p), style: AppTypography.bodySmall(context))),
                ],
              ),
            );
          })),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required Widget child}) {
    final isApple = AppTheme.isApplePlatform(context);
    final isDark = AppTheme.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTypography.labelSmall(context).copyWith(
            color: AppColors.textSecondary(context),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isApple
                ? (isDark ? AppColors.iosSurfaceDark : AppColors.iosSurface)
                : AppColors.surfaceContainerHigh(context),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: child,
        ),
      ],
    );
  }
}
