import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme.dart';

/// A single step in the help walkthrough.
class HelpStep {
  final IconData icon;
  final String title;
  final String description;

  const HelpStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}

/// Which page the help is for.
enum HelpPage { selectEvent, problems }

/// Shows a paginated help walkthrough as a bottom sheet.
///
/// Call [showHelpWalkthrough] to display it. Call [showHelpIfFirstVisit]
/// to auto-show on first visit only.
class HelpWalkthrough {
  static const _prefKeyPrefix = 'help_seen_';

  /// Show the walkthrough for the given page and role.
  static Future<void> show(
    BuildContext context, {
    required HelpPage page,
    required bool isCrewMember,
  }) {
    final steps = _getSteps(page, isCrewMember);
    return _showSheet(context, steps);
  }

  /// Show help only if the user hasn't seen it for this page+role combo.
  /// Uses a post-frame callback so it doesn't block the calling widget's build.
  static void showIfFirstVisit(
    BuildContext context, {
    required HelpPage page,
    required bool isCrewMember,
  }) {
    // Schedule after the current frame to avoid showing during build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final key = '$_prefKeyPrefix${page.name}_${isCrewMember ? 'crew' : 'ref'}';
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(key) == true) return;

      await prefs.setBool(key, true);

      if (!context.mounted) return;
      await show(context, page: page, isCrewMember: isCrewMember);
    });
  }

  /// Reset "seen" flags so help shows again.
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final page in HelpPage.values) {
      for (final role in ['crew', 'ref']) {
        await prefs.remove('$_prefKeyPrefix${page.name}_$role');
      }
    }
  }

  // ─── Step definitions ────────────────────────────────────────────────

  static List<HelpStep> _getSteps(HelpPage page, bool isCrewMember) {
    switch (page) {
      case HelpPage.selectEvent:
        return _selectEventSteps(isCrewMember);
      case HelpPage.problems:
        return isCrewMember ? _problemsCrewSteps : _problemsRefereeSteps;
    }
  }

  static List<HelpStep> _selectEventSteps(bool isCrewMember) {
    return [
      const HelpStep(
        icon: Icons.event,
        title: 'Welcome to StripCall',
        description:
            'This is the event list. Tap an event to enter it and start '
            'reporting or tracking problems.',
      ),
      const HelpStep(
        icon: Icons.circle,
        title: 'Live Events',
        description:
            'Events happening right now show a red LIVE badge. '
            'These appear at the top under "Happening Now".',
      ),
      const HelpStep(
        icon: Icons.badge,
        title: 'Your Role',
        description:
            'If you\'re on a crew, your assignment appears as a colored badge '
            'on each event (e.g. "Armorer" or "CC - Medical" for crew chiefs). '
            'Referees won\'t see a crew badge — that\'s normal.',
      ),
      const HelpStep(
        icon: Icons.search,
        title: 'Search',
        description:
            'Use the search bar to filter events by name, city, or state.',
      ),
      const HelpStep(
        icon: Icons.settings,
        title: 'Settings',
        description:
            'Tap the gear icon for your account, to manage events/crews '
            '(if you have permission), or to revisit this help guide.',
      ),
    ];
  }

  static const _problemsCrewSteps = [
    HelpStep(
      icon: Icons.list_alt,
      title: 'Your Problem List',
      description:
          'This screen shows all active problems for your crew, '
          'and any problems you report for other crews. '
          'New problems appear automatically as referees and others report them.',
    ),
    HelpStep(
      icon: Icons.touch_app,
      title: 'Expand a Problem',
      description:
          'Tap any problem card to expand it. You\'ll see the full details, '
          'chat messages, and action buttons.',
    ),
    HelpStep(
      icon: Icons.directions_run,
      title: 'On My Way',
      description:
          'Tap "On My Way" to let your crew and the reporter of the problem '
          'know you\'re heading to a strip. '
          'Your name appears on the card so others know help is coming.',
    ),
    HelpStep(
      icon: Icons.message,
      title: 'Problem Messages',
      description:
          'Each problem has its own message thread. Expand a problem to see it. '
          'Messages you send go to all crew members. Check "Include Reporter" '
          'to also send the message to the person who reported the problem.',
    ),
    HelpStep(
      icon: Icons.check_circle_outline,
      title: 'Resolve a Problem',
      description:
          'Tap "Resolve" to close out a problem. Select the action taken '
          'and optionally add notes about what you did.',
    ),
    HelpStep(
      icon: Icons.edit,
      title: 'Edit Symptom',
      description:
          'Need to reclassify? Tap "Edit Symptom" on an active problem '
          'to change the symptom category or strip number.',
    ),
    HelpStep(
      icon: Icons.chat_bubble_outline,
      title: 'Crew Chat',
      description:
          'The message area at the top lets you send messages to your crew. '
          'Messages about specific problems appear inside the problem card.',
    ),
    HelpStep(
      icon: Icons.add_circle_outline,
      title: 'Report a Problem',
      description:
          'You can also report a problem to any crew. Tap "Report Problem" '
          'at the bottom, select the crew, strip number, symptom category, '
          'and specific symptom.',
    ),
    HelpStep(
      icon: Icons.toggle_on,
      title: 'Resolved Problems',
      description:
          'Resolved problems disappear after 5 minutes. Toggle "Show resolved" '
          'to see them again. Superusers can un-resolve if needed.',
    ),
    HelpStep(
      icon: Icons.refresh,
      title: 'Live Updates',
      description:
          'Problems update automatically every 10 seconds. '
          'Tap the refresh icon at the bottom-left to force an immediate update.',
    ),
  ];

  static const _problemsRefereeSteps = [
    HelpStep(
      icon: Icons.add_circle_outline,
      title: 'Report a Problem',
      description:
          'Tap "Report Problem" at the bottom to report an issue you see on a strip. '
          'Select the crew type, strip number, and describe the problem.',
    ),
    HelpStep(
      icon: Icons.touch_app,
      title: 'Track Your Reports',
      description:
          'You\'ll see only the problems you\'ve reported. '
          'Tap a card to expand it and see its current status.',
    ),
    HelpStep(
      icon: Icons.visibility,
      title: 'Watch for Updates',
      description:
          'When a crew member responds with "On My Way", you\'ll see their name. '
          'When the problem is resolved, the card updates automatically.',
    ),
    HelpStep(
      icon: Icons.chat_bubble_outline,
      title: 'Problem Chat',
      description:
          'Expand a problem to see messages from the crew handling it. '
          'You can send messages to provide more detail about what you saw.',
    ),
    HelpStep(
      icon: Icons.refresh,
      title: 'Live Updates',
      description:
          'Your reported problems update automatically every 10 seconds. '
          'Resolved problems disappear after 5 minutes.',
    ),
  ];

  // ─── Bottom sheet UI ─────────────────────────────────────────────────

  static Future<void> _showSheet(
    BuildContext context,
    List<HelpStep> steps,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HelpSheet(steps: steps),
    );
  }
}

class _HelpSheet extends StatefulWidget {
  final List<HelpStep> steps;

  const _HelpSheet({required this.steps});

  @override
  State<_HelpSheet> createState() => _HelpSheetState();
}

class _HelpSheetState extends State<_HelpSheet> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < widget.steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previous() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApple = AppTheme.isApplePlatform(context);
    final isDark = AppTheme.isDark(context);
    final bgColor = isDark
        ? (isApple ? AppColors.iosSurfaceDark : AppColors.surfaceContainerHigh(context))
        : (isApple ? AppColors.iosSurface : AppColors.surfaceContainerHigh(context));
    final accentColor = AppColors.actionAccent(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary(context).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Skip / step counter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currentPage + 1} of ${widget.steps.length}',
                  style: AppTypography.bodySmall(context).copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
                if (isApple)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 15,
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Skip',
                      style: TextStyle(color: AppColors.textSecondary(context)),
                    ),
                  ),
              ],
            ),
          ),

          // Page content
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemCount: widget.steps.length,
              itemBuilder: (context, index) {
                final step = widget.steps[index];
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          step.icon,
                          size: 36,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        step.title,
                        style: AppTypography.titleLarge(context).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        step.description,
                        style: AppTypography.bodyMedium(context).copyWith(
                          color: AppColors.textSecondary(context),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Page dots + navigation
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              children: [
                // Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.steps.length, (index) {
                    final isActive = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? accentColor
                            : AppColors.textSecondary(context).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    if (_currentPage > 0) ...[
                      if (isApple)
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          onPressed: _previous,
                          child: Text(
                            'Back',
                            style: TextStyle(color: AppColors.textSecondary(context)),
                          ),
                        )
                      else
                        TextButton(
                          onPressed: _previous,
                          child: Text(
                            'Back',
                            style: TextStyle(color: AppColors.textSecondary(context)),
                          ),
                        ),
                    ],
                    const Spacer(),
                    if (isApple)
                      CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        onPressed: _next,
                        child: Text(
                          _currentPage < widget.steps.length - 1
                              ? 'Next'
                              : 'Got It',
                        ),
                      )
                    else
                      FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          _currentPage < widget.steps.length - 1
                              ? 'Next'
                              : 'Got It',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
