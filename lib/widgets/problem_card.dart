import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/problem_with_details.dart';
import '../theme/theme.dart';
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
  final bool isExpanded;
  final List<Map<String, dynamic>>? responders;
  final VoidCallback onToggleExpansion;
  final VoidCallback onResolve;
  final VoidCallback onGoOnMyWay;
  final VoidCallback onLoadMissingData;
  final VoidCallback? onEditSymptom;
  final VoidCallback? onUnresolve;

  const ProblemCard({
    super.key,
    required this.problem,
    required this.status,
    required this.currentUserId,
    required this.isReferee,
    required this.isUserResponding,
    required this.userCrewId,
    required this.isSuperUser,
    required this.isExpanded,
    this.responders,
    required this.onToggleExpansion,
    required this.onResolve,
    required this.onGoOnMyWay,
    required this.onLoadMissingData,
    this.onEditSymptom,
    this.onUnresolve,
  });

  @override
  State<ProblemCard> createState() => _ProblemCardState();
}

class _ProblemCardState extends State<ProblemCard> {
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

  bool get _canShowActions =>
      (widget.isSuperUser || widget.userCrewId == widget.problem.crewId) &&
      widget.problem.actionString == null &&
      !widget.problem.isResolved;

  // ---------------------------------------------------------------------------
  // Responder helpers
  // ---------------------------------------------------------------------------

  int get _responderCount => widget.responders?.length ?? 0;

  /// Short names for collapsed card: "K. Lee, P. Singh"
  String _getResponderNames() {
    if (widget.responders == null || widget.responders!.isEmpty) return '';
    return widget.responders!.map((r) {
      final user = r['user'] as Map<String, dynamic>?;
      if (user != null) {
        final first = user['firstname'] as String? ?? '';
        final last = user['lastname'] as String? ?? '';
        if (first.isNotEmpty && last.isNotEmpty) {
          return '${first[0]}. $last';
        }
        if (last.isNotEmpty) return last;
        return first;
      }
      return 'Unknown';
    }).join(', ');
  }

  /// Get last message preview text for collapsed card
  String? _getLastMessagePreview() {
    final msgs = widget.problem.messages;
    if (msgs == null || msgs.isEmpty) return null;
    final last = msgs.last;
    final text = last['message'] as String? ?? '';
    if (text.isEmpty) return null;
    // Truncate long messages
    return text.length > 50 ? '${text.substring(0, 50)}...' : text;
  }

  /// Status color based on problem status
  Color _statusColor(BuildContext context) {
    switch (widget.status) {
      case 'new':
        return AppColors.problemReported(context);
      case 'en_route':
        return AppColors.problemResponded(context);
      case 'resolved':
        return AppColors.problemResolved(context);
      default:
        return AppColors.textSecondary(context);
    }
  }

  /// Status label for badge
  String? get _statusLabel {
    switch (widget.status) {
      case 'resolved':
        return 'Resolved';
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Status & crew type badges
  // ---------------------------------------------------------------------------

  Widget _buildStatusBadge(BuildContext context) {
    final label = _statusLabel;
    if (label == null) return const SizedBox.shrink();
    final color = _statusColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCrewTypeBadge(BuildContext context) {
    final crewName = widget.problem.crewTypeName;
    if (crewName == null) return const SizedBox.shrink();
    final colors = AppColors.roleBadgeColors(context, crewName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        crewName,
        style: TextStyle(
          color: colors.foreground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Unread count badge (blue circle with number)
  // ---------------------------------------------------------------------------

  Widget _buildUnreadBadge() {
    final msgCount = widget.problem.messages?.length ?? 0;
    if (msgCount == 0) return const SizedBox.shrink();
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: AppColors.iosBlue,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$msgCount',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Responder count badge (green circle with number)
  // ---------------------------------------------------------------------------

  Widget _buildResponderBadge() {
    if (_responderCount == 0) return const SizedBox.shrink();
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.actionAccent(context),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$_responderCount',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Resolution info helpers
  // ---------------------------------------------------------------------------

  /// "Resolved 13:47 by T. Webb · Fixed on spot"
  String _resolvedSummary() {
    final parts = <String>[];
    parts.add('Resolved');
    if (widget.problem.resolvedDateTimeParsed != null) {
      parts.add(_formatTime(widget.problem.resolvedDateTimeParsed!));
    }
    if (widget.problem.actionByName != null) {
      parts.add('by ${widget.problem.actionByName}');
    }
    if (widget.problem.actionString != null) {
      parts.add('\u00B7 ${widget.problem.actionString}');
    }
    return parts.join(' ');
  }

  Widget _buildCollapsedResolvedInfo() {
    return Text(
      _resolvedSummary(),
      style: AppTypography.problemSubtitle(context).copyWith(
        color: AppColors.problemResolved(context),
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  // ---------------------------------------------------------------------------
  // Collapsed layout
  // ---------------------------------------------------------------------------

  Widget _buildCollapsedProblem() {
    final isApple = AppTheme.isApplePlatform(context);
    final lastMessage = _getLastMessagePreview();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: status dot, title, badges, expand chevron
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StatusIndicator(status: widget.status, size: 10),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Strip ${widget.problem.strip}${widget.problem.symptomString != null ? ': ${widget.problem.symptomString}' : ''}',
                style: AppTypography.problemTitle(context),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isApple ? CupertinoIcons.chevron_down : Icons.expand_more,
              size: 20,
              color: AppColors.textSecondary(context),
            ),
          ],
        ),

        const SizedBox(height: 4),

        // Row 2: subtitle
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: widget.problem.isResolved
              ? _buildCollapsedResolvedInfo()
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Reported by ${widget.problem.originatorName ?? 'Unknown'} \u00B7 ${_formatTime(widget.problem.startDateTime)}',
                        style: AppTypography.problemSubtitle(context).copyWith(
                          color: AppColors.textSecondary(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (_responderCount > 0) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Responded: ${_getResponderNames()}',
                          style: AppTypography.problemSubtitle(context).copyWith(
                            color: AppColors.problemResponded(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ],
                ),
        ),

        // Row 3: last message preview (if any, only for unresolved)
        if (!widget.problem.isResolved && lastMessage != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.iosBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lastMessage,
                    style: AppTypography.bodySmall(context).copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Expanded layout
  // ---------------------------------------------------------------------------

  Widget _buildExpandedProblem() {
    final accentColor = AppColors.actionAccent(context);
    final isApple = AppTheme.isApplePlatform(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: status dot + strip title + symptom + chevron
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StatusIndicator(status: widget.status, size: 12),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Strip ${widget.problem.strip}: ${widget.problem.symptomString ?? 'Unknown'}',
                style: AppTypography.problemTitle(context),
              ),
            ),
            _buildStatusBadge(context),
            const SizedBox(width: 4),
            IconButton(
              onPressed: widget.onToggleExpansion,
              icon: Icon(
                isApple ? CupertinoIcons.chevron_up : Icons.expand_less,
                size: 22,
                color: AppColors.textSecondary(context),
              ),
              padding: AppSpacing.paddingXs,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),

        // Reporter + time
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            'Reported by ${widget.problem.originatorName ?? 'Unknown'} \u00B7 ${_formatTime(widget.problem.startDateTime)}',
            style: AppTypography.timestamp(context),
          ),
        ),

        // Responders
        if (_responderCount > 0) ...[
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              'Responded: ${_getResponderNames()}',
              style: AppTypography.timestamp(context).copyWith(
                color: AppColors.problemResponded(context),
              ),
            ),
          ),
        ],

        // Resolution info (for resolved problems, show in green)
        if (widget.problem.isResolved) ...[
          AppSpacing.verticalXs,
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              _resolvedSummary(),
              style: AppTypography.bodySmall(context).copyWith(
                color: AppColors.problemResolved(context),
              ),
            ),
          ),
          // Unresolve button (right under the status/resolution info)
          if (widget.onUnresolve != null) ...[
            AppSpacing.verticalSm,
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20),
              child: SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  key: ValueKey(
                    'problem_unresolve_button_${widget.problem.id}',
                  ),
                  onTap: widget.onUnresolve,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFFF6B6B),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Center(
                      child: Text(
                        'Unresolve',
                        style: TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ] else ...[
          if (widget.problem.actionString != null) ...[
            AppSpacing.verticalXs,
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                'Resolution: ${widget.problem.actionString}',
                style: AppTypography.bodySmall(context),
              ),
            ),
          ],
          if (widget.problem.notes?.isNotEmpty ?? false) ...[
            AppSpacing.verticalXs,
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                'Notes: ${widget.problem.notes}',
                style: AppTypography.bodySmall(context),
              ),
            ),
          ],
        ],

        // Action buttons row (only for unresolved problems)
        if (_canShowActions) ...[
          AppSpacing.verticalSm,
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Row(
              children: [
                // On my way / En route
                if (!widget.isUserResponding)
                  Semantics(
                    identifier: 'problem_onmyway_button_${widget.problem.id}',
                    child: _buildOutlinedButton(
                      key: ValueKey(
                        'problem_onmyway_button_${widget.problem.id}',
                      ),
                      label: 'On my way',
                      onPressed: widget.onGoOnMyWay,
                      color: accentColor,
                      isApple: isApple,
                    ),
                  )
                else
                  Semantics(
                    identifier: 'problem_enroute_button_${widget.problem.id}',
                    child: _buildFilledButton(
                      key: ValueKey(
                        'problem_enroute_button_${widget.problem.id}',
                      ),
                      label: 'En route',
                      onPressed: null,
                      color: AppColors.problemResponded(context),
                      isApple: isApple,
                    ),
                  ),
                AppSpacing.horizontalSm,

                // Resolve
                Semantics(
                  identifier: 'problem_resolve_button_${widget.problem.id}',
                  child: _buildFilledButton(
                    key: ValueKey(
                      'problem_resolve_button_${widget.problem.id}',
                    ),
                    label: 'Resolve',
                    onPressed: widget.onResolve,
                    color: accentColor,
                    isApple: isApple,
                  ),
                ),
                AppSpacing.horizontalSm,

                // Edit text link
                if (widget.onEditSymptom != null)
                  GestureDetector(
                    key: ValueKey(
                      'problem_edit_symptom_button_${widget.problem.id}',
                    ),
                    onTap: widget.onEditSymptom,
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],

        AppSpacing.verticalSm,

        // Problem description line ("Problem: Blade broken" + Edit) - only for unresolved
        // MESSAGES section
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProblemChat(
                messages: widget.problem.messages,
                problemId: widget.problem.id,
                crewId: widget.problem.crewId,
                originator: widget.problem.originatorId,
                currentUserId: widget.currentUserId,
                isCrewMember:
                    widget.userCrewId != null &&
                    widget.userCrewId == widget.problem.crewId,
                isSuperUser: widget.isSuperUser,
                readOnly: widget.problem.isResolved,
              ),
            ],
          ),
        ),


      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Button builders
  // ---------------------------------------------------------------------------

  Widget _buildFilledButton({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
    required bool isApple,
  }) {
    final borderRadius = BorderRadius.circular(20);
    if (isApple) {
      return CupertinoButton(
        key: key,
        onPressed: onPressed,
        color: onPressed != null ? color : color.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        minimumSize: Size.zero,
        borderRadius: borderRadius,
        child: Text(
          label,
          style: TextStyle(
            color: onPressed != null ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return ElevatedButton(
      key: key,
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }

  Widget _buildOutlinedButton({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
    required bool isApple,
  }) {
    final borderRadius = BorderRadius.circular(20);
    if (isApple) {
      return GestureDetector(
        key: key,
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.5),
            borderRadius: borderRadius,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final content = widget.isExpanded
        ? _buildExpandedProblem()
        : _buildCollapsedProblem();

    return Semantics(
      identifier: 'problem_card_${widget.problem.id}',
      child: Card(
        key: ValueKey('problem_card_${widget.problem.id}'),
        child: widget.isExpanded
            ? ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: content,
                ),
              )
            : InkWell(
                onTap: widget.onToggleExpansion,
                borderRadius: AppSpacing.borderRadiusLg,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: content,
                ),
              ),
      ),
    );
  }
}
