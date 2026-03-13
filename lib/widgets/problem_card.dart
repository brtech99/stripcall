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

  /// Short names for collapsed card: "John D., Sarah M."
  String _getResponderNames() {
    if (widget.responders == null || widget.responders!.isEmpty) return '';
    return widget.responders!.map((r) {
      final user = r['user'] as Map<String, dynamic>?;
      if (user != null) {
        final first = user['firstname'] as String? ?? '';
        final last = user['lastname'] as String? ?? '';
        if (last.isNotEmpty) return '$first ${last[0]}.';
        return first;
      }
      return 'Unknown';
    }).join(', ');
  }

  /// Third line of collapsed card: responder summary or reporter info
  String _getCollapsedSubline() {
    if (_responderCount > 0) {
      final names = _getResponderNames();
      final isMe = widget.responders!.any(
        (r) => r['user_id'] == widget.currentUserId,
      );
      final parts = <String>[
        '$names responding',
        if (isMe) 'You',
        _formatTime(widget.problem.startDateTime),
      ];
      return parts.join(' \u2022 ');
    }
    return '${widget.problem.originatorName ?? 'Unknown'} \u2022 ${_formatTime(widget.problem.startDateTime)}';
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
  // Collapsed layout
  // ---------------------------------------------------------------------------

  Widget _buildCollapsedProblem() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: StatusIndicator(status: widget.status),
        ),
        AppSpacing.horizontalSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Strip ${widget.problem.strip}',
                style: AppTypography.problemTitle(context),
              ),
              const SizedBox(height: 2),
              Text(
                widget.problem.symptomString ?? 'Unknown',
                style: AppTypography.bodyMedium(context),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                _getCollapsedSubline(),
                style: AppTypography.problemSubtitle(context).copyWith(
                  color: AppColors.textSecondary(context),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        AppSpacing.horizontalSm,
        _buildResponderBadge(),
        IconButton(
          onPressed: widget.onToggleExpansion,
          icon: Icon(
            Icons.expand_more,
            size: AppSpacing.iconMd,
            color: AppColors.textSecondary(context),
          ),
          padding: AppSpacing.paddingXs,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
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
        // Header: status dot + strip title + chevron
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: StatusIndicator(status: widget.status),
            ),
            AppSpacing.horizontalSm,
            Expanded(
              child: Text(
                'Strip ${widget.problem.strip}',
                style: AppTypography.problemTitle(context),
              ),
            ),
            IconButton(
              onPressed: widget.onToggleExpansion,
              icon: Icon(
                Icons.expand_less,
                size: 28,
                color: AppColors.textSecondary(context),
              ),
              padding: AppSpacing.paddingSm,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ],
        ),

        // Symptom description
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            widget.problem.symptomString ?? 'Unknown',
            style: AppTypography.bodyMedium(context),
          ),
        ),
        AppSpacing.verticalXs,

        // Reporter + time
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            'Reported by ${widget.problem.originatorName ?? 'Unknown'} \u2022 ${_formatTime(widget.problem.startDateTime)}',
            style: AppTypography.timestamp(context),
          ),
        ),

        // Resolution info
        if (widget.problem.actionString != null) ...[
          AppSpacing.verticalXs,
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text('Resolution: ${widget.problem.actionString}'),
          ),
        ],
        if (widget.problem.notes?.isNotEmpty ?? false) ...[
          AppSpacing.verticalXs,
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text('Notes: ${widget.problem.notes}'),
          ),
        ],
        if (widget.problem.isResolved &&
            widget.problem.actionByName != null) ...[
          AppSpacing.verticalXs,
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              'Resolved by: ${widget.problem.actionByName}',
              style: AppTypography.successText(context),
            ),
          ),
        ],

        // Action buttons row
        if (_canShowActions) ...[
          AppSpacing.verticalSm,
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Row(
              children: [
                // On my way / En route (filled)
                if (!widget.isUserResponding)
                  Semantics(
                    identifier: 'problem_onmyway_button_${widget.problem.id}',
                    child: _buildFilledButton(
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
                      color: AppColors.statusWarning,
                      isApple: isApple,
                    ),
                  ),
                AppSpacing.horizontalSm,

                // Resolve: solid when user is responding, outlined otherwise
                Semantics(
                  identifier: 'problem_resolve_button_${widget.problem.id}',
                  child: widget.isUserResponding
                      ? _buildFilledButton(
                          key: ValueKey(
                            'problem_resolve_button_${widget.problem.id}',
                          ),
                          label: 'Resolve',
                          onPressed: widget.onResolve,
                          color: accentColor,
                          isApple: isApple,
                        )
                      : _buildOutlinedButton(
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

                // Edit (outlined icon button)
                if (widget.onEditSymptom != null)
                  _buildEditIconButton(
                    key: ValueKey(
                      'problem_edit_symptom_button_${widget.problem.id}',
                    ),
                    onPressed: widget.onEditSymptom!,
                    color: accentColor,
                    isApple: isApple,
                  ),
              ],
            ),
          ),
        ],

        AppSpacing.verticalSm,

        // MESSAGES header
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MESSAGES',
                style: AppTypography.labelSmall(context).copyWith(
                  color: AppColors.textSecondary(context),
                  letterSpacing: 1.0,
                ),
              ),
              AppSpacing.verticalSm,
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
    final borderRadius = BorderRadius.circular(8);
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
    final borderRadius = BorderRadius.circular(8);
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
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }

  Widget _buildEditIconButton({
    Key? key,
    required VoidCallback onPressed,
    required Color color,
    required bool isApple,
  }) {
    return GestureDetector(
      key: key,
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: AppSpacing.borderRadiusMd,
        ),
        child: Icon(Icons.edit_outlined, size: 18, color: color),
      ),
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
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: content,
                ),
              ),
      ),
    );
  }
}
