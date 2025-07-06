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
  final VoidCallback onToggleExpansion;
  final VoidCallback onResolve;
  final VoidCallback onGoOnMyWay;
  final VoidCallback onLoadMissingData;
  
  const ProblemCard({
    super.key,
    required this.problem,
    required this.status,
    required this.currentUserId,
    required this.isReferee,
    required this.isUserResponding,
    required this.userCrewId,
    required this.onToggleExpansion,
    required this.onResolve,
    required this.onGoOnMyWay,
    required this.onLoadMissingData,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusIndicator(status: widget.status),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Strip ${widget.problem.strip}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Problem: ${widget.problem.symptomString ?? 'Unknown'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Reported by ${widget.problem.originatorName ?? 'Unknown'} ${_formatTime(widget.problem.startDateTime)}',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
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
            size: 28,
            color: Colors.grey[600],
          ),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
            if (!widget.isReferee && widget.problem.actionString == null && !widget.problem.isResolved) ...[
              if (!widget.isUserResponding)
                ElevatedButton(
                  onPressed: widget.onGoOnMyWay,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('On my way'),
                )
              else
                ElevatedButton(
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
        Text(
          'Problem: ${widget.problem.symptomString ?? 'Unknown'}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
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
        Text(
          'Reported by ${widget.problem.originatorName ?? 'Unknown'} ${_formatTime(widget.problem.startDateTime)}',
          style: Theme.of(context).textTheme.bodySmall,
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