import 'package:flutter/material.dart';
import '../models/problem_with_details.dart';
import 'status_indicator.dart';
import 'problem_chat.dart';

class ProblemCard extends StatefulWidget {
  final ProblemWithDetails problem;
  final String status;
  final String? currentUserId;
  final bool isReferee;
  final bool isUserResponding;
  final int? userCrewId;
  final bool isSuperUser;
  final List<Map<String, dynamic>>? responders;
  final VoidCallback onToggleExpansion;
  final VoidCallback onResolve;
  final VoidCallback onGoOnMyWay;
  final VoidCallback onLoadMissingData;
  final VoidCallback? onEditSymptom;

  const ProblemCard({
    super.key,
    required this.problem,
    required this.status,
    required this.currentUserId,
    required this.isReferee,
    required this.isUserResponding,
    required this.userCrewId,
    required this.isSuperUser,
    this.responders,
    required this.onToggleExpansion,
    required this.onResolve,
    required this.onGoOnMyWay,
    required this.onLoadMissingData,
    this.onEditSymptom,
  });

  @override
  State<ProblemCard> createState() => _ProblemCardState();
}

class _ProblemCardState extends State<ProblemCard> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    widget.onLoadMissingData();
  }

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildCollapsedProblem() {
    // Get the latest message if available, filtering based on user's access
    String? latestMessage;
    if (widget.problem.messages != null && widget.problem.messages!.isNotEmpty) {
      // Filter messages based on user's crew membership
      final isUserCrew = widget.userCrewId != null && widget.problem.crewId == widget.userCrewId;
      final visibleMessages = widget.problem.messages!.where((msg) {
        if (isUserCrew || widget.isSuperUser) {
          return true; // Crew members and superusers see all messages
        }
        // Non-crew members see messages marked for them OR messages they authored
        final includeReporter = msg['include_reporter'];
        final isAuthor = msg['author'] == widget.currentUserId;
        return isAuthor || includeReporter == null || includeReporter == true;
      }).toList();

      if (visibleMessages.isNotEmpty) {
        final sortedMessages = List.from(visibleMessages);
        sortedMessages.sort((a, b) {
          final aTime = DateTime.parse(a['created_at']);
          final bTime = DateTime.parse(b['created_at']);
          return bTime.compareTo(aTime); // Descending order
        });
        latestMessage = sortedMessages.first['message'] as String?;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusIndicator(status: widget.status),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Strip ${widget.problem.strip}: ${widget.problem.symptomString ?? 'Unknown'}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                latestMessage ?? 'Reported by ${widget.problem.originatorName ?? 'Unknown'} ${_formatTime(widget.problem.startDateTime)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: latestMessage != null ? FontStyle.italic : null,
                  color: latestMessage != null ? Colors.grey[700] : null,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() => _isExpanded = !_isExpanded);
            widget.onToggleExpansion();
          },
          icon: Icon(
            Icons.expand_more,
            size: 24,
            color: Colors.grey[600],
          ),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    );
  }

  Widget _buildExpandedProblem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatusIndicator(status: widget.status),
            const SizedBox(width: 8),
            SizedBox(
              width: 80, // Fixed width for strip text
              child: Text(
                'Strip ${widget.problem.strip}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Only show buttons if user is superuser OR user's crew matches problem's crew
            if ((widget.isSuperUser || widget.userCrewId == widget.problem.crewId) && widget.problem.actionString == null && !widget.problem.isResolved) ...[
              if (!widget.isUserResponding)
                ElevatedButton(
                  key: ValueKey('problem_onmyway_button_${widget.problem.id}'),
                  onPressed: widget.onGoOnMyWay,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('On my way'),
                )
              else
                ElevatedButton(
                  key: ValueKey('problem_enroute_button_${widget.problem.id}'),
                  onPressed: null, // Disabled
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('En route'),
                ),
              const SizedBox(width: 20),
              ElevatedButton(
                key: ValueKey('problem_resolve_button_${widget.problem.id}'),
                onPressed: widget.onResolve,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Resolve'),
              ),
            ],
            const Spacer(),
            IconButton(
              onPressed: () {
                setState(() => _isExpanded = !_isExpanded);
                widget.onToggleExpansion();
              },
              icon: Icon(
                Icons.expand_less,
                size: 28,
                color: Colors.grey[600],
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Problem: ${widget.problem.symptomString ?? 'Unknown'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Show Edit button for crew members and superusers on unresolved problems
            if (widget.onEditSymptom != null &&
                (widget.isSuperUser || widget.userCrewId == widget.problem.crewId) &&
                !widget.problem.isResolved)
              TextButton.icon(
                key: ValueKey('problem_edit_symptom_button_${widget.problem.id}'),
                onPressed: widget.onEditSymptom,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),

        if (widget.problem.actionString != null) ...[
          const SizedBox(height: 4),
          Text('Resolution: ${widget.problem.actionString}'),
        ],
        if (widget.problem.notes?.isNotEmpty ?? false) ...[
          const SizedBox(height: 4),
          Text('Notes: ${widget.problem.notes}'),
        ],
        if (widget.problem.isResolved && widget.problem.actionByName != null) ...[
          const SizedBox(height: 4),
          Text(
            'Resolved by: ${widget.problem.actionByName}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ],
        const SizedBox(height: 4),
        ProblemChat(
          messages: widget.problem.messages,
          problemId: widget.problem.id,
          crewId: widget.problem.crewId,
          originator: widget.problem.originatorName ?? 'Unknown',
          currentUserId: widget.currentUserId,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reported by ${widget.problem.originatorName ?? 'Unknown'} ${_formatTime(widget.problem.startDateTime)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.responders != null && widget.responders!.isNotEmpty)
              Text(
                '${widget.problem.isResolved ? 'Responded' : 'Responding'}: ${widget.responders!.map((r) {
                  final user = r['user'] as Map<String, dynamic>?;
                  if (user != null) {
                    return '${user['firstname']} ${user['lastname']}';
                  }
                  return 'Unknown';
                }).join(', ')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: widget.problem.isResolved ? Colors.grey[600] : Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        if (widget.problem.isResolved && widget.problem.actionByName != null) ...[
          const SizedBox(height: 1),
          Text(
            'Resolved by ${widget.problem.actionByName ?? 'Unknown'} ${_formatTime(widget.problem.resolvedDateTimeParsed!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('problem_card_${widget.problem.id}'),
      child: InkWell(
        onTap: () {
          setState(() => _isExpanded = !_isExpanded);
          widget.onToggleExpansion();
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: _isExpanded ? _buildExpandedProblem() : _buildCollapsedProblem(),
        ),
      ),
    );
  }
}
