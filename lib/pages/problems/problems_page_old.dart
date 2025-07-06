import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'new_problem_dialog.dart';
import 'resolve_problem_dialog.dart';
import 'dart:async';
import '../../widgets/settings_menu.dart';
import '../../widgets/crew_message_window.dart';
import '../../models/problem_with_details.dart';
import '../../services/notification_service.dart';

// Helper widget for message bubble
class MessageBubble extends StatelessWidget {
  final String text;
  final String senderName;
  final bool isMe;
  final DateTime createdAt;
  final String? displayStyle;
  
  const MessageBubble({
    super.key,
    required this.text,
    required this.senderName,
    required this.isMe,
    required this.createdAt,
    this.displayStyle,
  });
  
  String _formatSenderName(String fullName) {
    if (displayStyle == 'firstInitial-Last') {
      final parts = fullName.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1]}';
      }
    }
    return fullName;
  }
  
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          final timeString = '${createdAt.toLocal().hour.toString().padLeft(2, '0')}:${createdAt.toLocal().minute.toString().padLeft(2, '0')}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sent at $timeString'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMe ? Theme.of(context).colorScheme.primary.withAlpha((0.2 * 255).toInt()) : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isMe ? text : '${_formatSenderName(senderName)}: $text',
            style: TextStyle(
              color: isMe ? Theme.of(context).colorScheme.onPrimary : null,
            ),
          ),
        ),
      ),
    );
  }
}

class ProblemChat extends StatefulWidget {
  final List<dynamic>? messages;
  final int problemId;
  final int crewId;
  final dynamic originator;
  final String? currentUserId;
  const ProblemChat({
    super.key,
    required this.messages,
    required this.problemId,
    required this.crewId,
    required this.originator,
    required this.currentUserId,
  });
  @override
  State<ProblemChat> createState() => _ProblemChatState();
}

class _ProblemChatState extends State<ProblemChat> {
  final TextEditingController _messageController = TextEditingController();
  bool _includeReporter = false;
  final Map<String, String> _userNameCache = {};
  String? _crewDisplayStyle;
  List<Map<String, dynamic>> _messages = [];
  
  @override
  void initState() {
    super.initState();
    _loadCrewDisplayStyle();
    _messages = List<Map<String, dynamic>>.from(widget.messages ?? []);
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
  
  Future<void> _loadCrewDisplayStyle() async {
    try {
      final response = await Supabase.instance.client
          .from('crews')
          .select('display_style')
          .eq('id', widget.crewId)
          .maybeSingle();
      
      if (mounted && response != null) {
        setState(() {
          _crewDisplayStyle = response['display_style'] as String?;
        });
      }
    } catch (e) {
      // Error loading crew display style
    }
  }
  
  Future<String> _getUserName(String userId) async {
    // Check cache first
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }
    
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('firstname, lastname')
          .eq('supabase_id', userId)
          .maybeSingle();
      
      if (response != null) {
        final firstName = response['firstname'] as String? ?? '';
        final lastName = response['lastname'] as String? ?? '';
        final fullName = '$firstName $lastName'.trim();
        
        if (mounted) {
          setState(() {
            _userNameCache[userId] = fullName;
          });
        }
        return fullName;
      }
    } catch (e) {
      // Error loading user data
    }
    
    // Fallback: show first 8 characters of user ID
    final fallbackName = 'User ${userId.substring(0, 8)}...';
    _userNameCache[userId] = fallbackName;
    return fallbackName;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _messages.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No messages yet'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  itemCount: _messages.length,
                  itemBuilder: (context, idx) {
                    final msg = _messages[idx];
                    final isMe = msg['author'] == widget.currentUserId;
                    
                    return FutureBuilder<String>(
                      future: _getUserName(msg['author']),
                      builder: (context, snapshot) {
                        final senderName = snapshot.data ?? 'Loading...';
                        
                        return MessageBubble(
                          text: msg['message'],
                          senderName: senderName,
                          isMe: isMe,
                          createdAt: DateTime.parse(msg['created_at']),
                          displayStyle: _crewDisplayStyle,
                        );
                      },
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send, size: 24),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final text = _messageController.text.trim();
                if (text.isEmpty) return;
                try {
                  final now = DateTime.now().toUtc();
                  final insertData = {
                    'problem': widget.problemId,
                    'crew': widget.crewId,
                    'author': widget.currentUserId,
                    'message': text,
                    'created_at': now.toIso8601String(),
                    'include_reporter': _includeReporter,
                  };
                  final result = await Supabase.instance.client.from('messages').insert(insertData).select().maybeSingle();
                  if (!mounted) return;
                  setState(() {
                    _messageController.clear();
                    // Add the new message to the local list immediately
                    _messages.add(result ?? insertData);
                  });
                  
                  // Send notification for the new message
                  await NotificationService().sendCrewNotification(
                    title: 'New Message',
                    body: text.length > 50 ? '${text.substring(0, 50)}...' : text,
                    crewId: widget.crewId.toString(),
                    senderId: widget.currentUserId!,
                    data: {
                      'type': 'new_message',
                      'problemId': widget.problemId.toString(),
                      'crewId': widget.crewId.toString(),
                    },
                    includeReporter: _includeReporter, // Use the checkbox setting
                  );
                  
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Message sent')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to send message: $e')),
                  );
                }
              },
            ),
          ],
        ),
        Row(
          children: [
            Checkbox(
              value: _includeReporter,
              onChanged: (val) => setState(() => _includeReporter = val ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const Text('Include reporter', style: TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class ProblemsPage extends StatefulWidget {
  final int eventId;
  final int? crewId;
  final String? crewType;

  const ProblemsPage({
    super.key,
    required this.eventId,
    required this.crewId,
    required this.crewType,
  });

  @override
  State<ProblemsPage> createState() => _ProblemsPageState();
}

class _ProblemsPageState extends State<ProblemsPage> {
  List<ProblemWithDetails> _problems = [];
  bool _isLoading = true;
  String? _error;
  bool _isReferee = false;
  Timer? _cleanupTimer;
  Timer? _updateTimer;
  int? _userCrewId;
  String? _userCrewName;
  bool _isSuperUser = false;
  List<Map<String, dynamic>> _allCrews = [];
  int? _selectedCrewId;
  final Set<int> _expandedProblems = {}; // Track which problems are expanded
  Map<int, List<Map<String, dynamic>>> _responders = {}; // Track responders for each problem

  @override
  void initState() {
    super.initState();
    _checkSuperUserStatus();
    _determineUserCrewInfo();
    _loadCrewInfo();
    _loadProblems();
    _loadEventInfo();
    // Start cleanup timer
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) => _cleanupResolvedProblems());
    // Start update timer
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkForUpdates());
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    if (!mounted) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Get the latest problem update time
      final latestProblemTime = _problems.isNotEmpty 
          ? _problems.map((p) => p.startDateTime).reduce((a, b) => a.isAfter(b) ? a : b)
          : DateTime(1970);

      // Get the latest message time - for now, we'll use the problem start time since messages are handled separately
      final latestMessageTime = latestProblemTime;

      await _checkForNewProblems(latestProblemTime);
      await _checkForNewMessages(latestMessageTime);
      await _checkForResolvedProblems(latestProblemTime);
    } catch (e) {
      // Error checking for updates
    }
  }

  Future<void> _checkForNewMessages(DateTime since) async {
    if (!mounted) return;

    try {
      if (_problems.isEmpty) return;

      final problemIds = _problems.map((p) => p.id).toList();
      final problemIdsStr = problemIds.join(',');
      
      final newMessages = await Supabase.instance.client
          .rpc('get_new_messages', params: {
            'since_time': since.toIso8601String(),
            'problem_ids': problemIdsStr,
          });

      if (mounted && newMessages != null && newMessages.isNotEmpty) {
        for (final message in newMessages) {
          await _handleNewMessage(message as Map<String, dynamic>);
        }
      }
    } catch (e) {
      // Error checking for new messages
    }
  }

  Future<void> _checkForNewProblems(DateTime since) async {
    if (!mounted) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final params = <String, dynamic>{
        'event_id': widget.eventId,
        'since_time': since.toIso8601String(),
        'user_id': userId,
      };
      if (widget.crewId != null) {
        params['crew_id'] = widget.crewId;
      }
      final newProblems = await Supabase.instance.client
          .rpc('get_new_problems_wrapper', params: params);
      if (mounted && newProblems != null && newProblems.isNotEmpty) {
        for (final problem in newProblems) {
          try {
            if (problem is Map<String, dynamic>) {
              await _handleNewProblem(problem);
            } else {
              // Unexpected problem data type
            }
          } catch (e) {
            // Error handling new problem
          }
        }
      }
    } catch (e) {
      // Error checking for new problems
    }
  }

  Future<void> _checkForResolvedProblems(DateTime since) async {
    if (!mounted || widget.crewId == null) return;

    try {
      final resolvedProblems = await Supabase.instance.client
          .rpc('get_resolved_problems', params: {
            'event_id': widget.eventId,
            'crew_id': widget.crewId,
            'since_time': since.toIso8601String(),
          });

      if (mounted && resolvedProblems != null && resolvedProblems.isNotEmpty) {
        for (final resolved in resolvedProblems) {
          try {
            // Try both column names since the database function might be inconsistent
            String? resolvedTimeStr;
            if (resolved.containsKey('enddatetime')) {
              resolvedTimeStr = resolved['enddatetime'] as String?;
            } else if (resolved.containsKey('resolveddatetime')) {
              resolvedTimeStr = resolved['resolveddatetime'] as String?;
            }
            
            if (resolvedTimeStr != null) {
              final resolvedTime = DateTime.parse(resolvedTimeStr);
              await _handleProblemResolved(
                (resolved['id'] as num).toInt(),
                resolvedTime,
              );
            }
          } catch (e) {
            // Error handling resolved problem
          }
        }

        // Remove problems that were resolved more than 5 minutes ago
        setState(() {
          _problems.removeWhere((problem) {
            if (problem.resolvedDateTimeParsed == null) return false;
            return DateTime.now().difference(problem.resolvedDateTimeParsed!).inMinutes >= 5;
          });
        });
      }
    } catch (e) {
      // Continue working even if this fails - it's not critical for basic functionality
    }
  }

  Future<void> _handleNewProblem(Map<String, dynamic> problemJson) async {
    if (!mounted) return;

    final problemWithDetails = ProblemWithDetails.fromJson(problemJson);
    
    // Filter out resolved problems that are older than 5 minutes
    if (problemWithDetails.resolvedDateTimeParsed != null) {
      final resolvedTime = problemWithDetails.resolvedDateTimeParsed!;
      final now = DateTime.now();
      final minutesSinceResolved = now.difference(resolvedTime).inMinutes;
      
      if (minutesSinceResolved >= 5) {
        // Skip this problem - it was resolved more than 5 minutes ago
        return;
      }
    }
    
    setState(() {
      // Only add if the problem doesn't already exist
      if (!_problems.any((p) => p.id == problemWithDetails.id)) {
        _problems.add(problemWithDetails);
        _problems.sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
      }
    });
  }

  Future<void> _handleNewMessage(Map<String, dynamic> message) async {
    if (!mounted) return;

    setState(() {
      final problemId = message['problem'] as int;
      final problemIndex = _problems.indexWhere((p) => p.id == problemId);
      if (problemIndex != -1) {
        final problem = _problems[problemIndex];
        final updatedMessages = <Map<String, dynamic>>[...(problem.messages ?? [])];
        
        // Check if message already exists to prevent duplicates
        final messageId = message['id'] as int;
        final messageExists = updatedMessages.any((m) => m['id'] == messageId);
        
        if (!messageExists) {
          updatedMessages.add(message);
          _problems[problemIndex] = problem.copyWith(messages: updatedMessages);
        }
      }
    });
  }

  Future<void> _handleProblemResolved(int problemId, DateTime resolvedTime) async {
    if (!mounted) return;

    setState(() {
      final problemIndex = _problems.indexWhere((p) => p.id == problemId);
      if (problemIndex != -1) {
        final problem = _problems[problemIndex];
        _problems[problemIndex] = problem.copyWith(
          resolvedDateTime: resolvedTime.toIso8601String(),
        );
      }
    });
  }

  Future<void> _cleanupResolvedProblems() async {
    if (!mounted) return;

    final now = DateTime.now();
    final resolvedProblems = _problems.where((problem) {
      if (problem.resolvedDateTimeParsed == null) return false;
      return now.difference(problem.resolvedDateTimeParsed!).inMinutes >= 5; // Remove after 5 minutes
    }).toList();

    if (resolvedProblems.isNotEmpty) {
      setState(() {
        _problems.removeWhere((problem) => resolvedProblems.contains(problem));
      });
    }
  }

  Future<void> _loadCrewInfo() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Check if user is a crew member
      if (widget.crewId != null) {
        final crewMemberResponse = await Supabase.instance.client
            .from('crewmembers')
            .select('crew:crew(id, crewtype:crewtypes(crewtype))')
            .eq('crew', widget.crewId!)
            .eq('crewmember', userId)
            .maybeSingle();

        // Get crew info

        if (mounted) {
          setState(() {
            _isReferee = crewMemberResponse == null;
          });
        }
      }
    } catch (e) {
      // Error loading crew info
    }
  }

  Future<void> _loadProblems() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');
      final params = <String, dynamic>{
        'event_id': widget.eventId,
        'since_time': DateTime(1970).toIso8601String(),
        'user_id': userId,
      };
      
      // For superusers, use selected crew; for regular users, use their crew
      final crewId = _isSuperUser ? _selectedCrewId : widget.crewId;
      if (crewId != null) {
        params['crew_id'] = crewId;
      }
      
      final response = await Supabase.instance.client
          .rpc('get_new_problems_wrapper', params: params);
      if (mounted) {
        final problems = <ProblemWithDetails>[];
        if (response != null) {
          for (final json in response) {
            try {
              if (json is Map<String, dynamic>) {
                final problem = ProblemWithDetails.fromJson(json);
                
                // Filter out resolved problems that are older than 5 minutes
                if (problem.resolvedDateTimeParsed != null) {
                  final resolvedTime = problem.resolvedDateTimeParsed!;
                  final now = DateTime.now();
                  final minutesSinceResolved = now.difference(resolvedTime).inMinutes;
                  
                  if (minutesSinceResolved >= 5) {
                    // Skip this problem - it was resolved more than 5 minutes ago
                    continue;
                  }
                }
                
                problems.add(problem);
              } else {
                // Unexpected problem data type
              }
            } catch (e) {
              // Error parsing problem
            }
          }
        }
        setState(() {
          _problems = problems;
          _isLoading = false;
        });
        
        // Load responders data after problems are loaded
        await _loadResponders();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load problems: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadEventInfo() async {
    try {
      if (mounted) {
        setState(() {
        });
      }
    } catch (e) {
      // Error loading event info
    }
  }

  Future<void> _showNewProblemDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => NewProblemDialog(
        eventId: widget.eventId,
        crewId: widget.crewId,
        crewType: widget.crewType,
      ),
    );

    if (result == true) {
      _loadProblems();
    }
  }

  Future<void> _showResolveDialog(int problemId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ResolveProblemDialog(
        problemId: problemId,
        eventId: widget.eventId,
        crewId: widget.crewId,
        crewType: widget.crewType,
      ),
    );

    if (result == true) {
      _loadProblems();
    }
  }

  Future<void> _determineUserCrewInfo() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final crewMember = await Supabase.instance.client
          .from('crewmembers')
          .select('''
            crew:crew(
              id, 
              event,
              crewtype:crewtypes(crewtype)
            )
          ''')
          .eq('crewmember', userId)
          .eq('crew.event', widget.eventId)
          .maybeSingle();
      if (crewMember != null && crewMember['crew'] != null) {
        final crew = crewMember['crew'] as Map<String, dynamic>;
        final crewTypeData = crew['crewtype'] as Map<String, dynamic>?;
        final crewTypeName = crewTypeData?['crewtype'] as String? ?? 'Crew';
        
        setState(() {
          _userCrewId = crew['id'] as int;
          _userCrewName = crewTypeName;
        });
      } else {
        setState(() {
          _userCrewId = null;
          _userCrewName = null;
        });
      }
    } catch (e) {
      // Error determining user crew info
      setState(() {
        _userCrewId = null;
        _userCrewName = null;
      });
    }
  }

  Future<void> _loadMissingSymptomData(ProblemWithDetails problem) async {
    if (problem.symptom != null) return; // Already has symptom data
    
    try {
      final symptomResponse = await Supabase.instance.client
          .from('symptom')
          .select('id, symptomstring')
          .eq('id', problem.symptomId)
          .maybeSingle();
      
      if (symptomResponse != null) {
        setState(() {
          final problemIndex = _problems.indexWhere((p) => p.id == problem.id);
          if (problemIndex != -1) {
            final updatedProblem = _problems[problemIndex].copyWith(
              symptom: symptomResponse,
            );
            _problems[problemIndex] = updatedProblem;
          }
        });
      }
    } catch (e) {
      // Error loading symptom data
    }
  }

  Future<void> _checkSuperUserStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('superuser')
          .eq('supabase_id', userId)
          .maybeSingle();
      
      if (mounted) {
        setState(() {
          _isSuperUser = userResponse?['superuser'] == true;
        });
        
        if (_isSuperUser) {
          _loadAllCrews();
        }
      }
    } catch (e) {
      // Error checking superuser status
    }
  }

  Future<void> _loadAllCrews() async {
    try {
      final response = await Supabase.instance.client
          .from('crews')
          .select('''
            id, 
            crewtype:crewtypes(crewtype),
            crew_chief:users(firstname, lastname)
          ''')
          .eq('event', widget.eventId)
          .order('crewtype(crewtype)');
      
      if (mounted) {
        setState(() {
          _allCrews = List<Map<String, dynamic>>.from(response);
          if (_selectedCrewId == null && _allCrews.isNotEmpty) {
            _selectedCrewId = _allCrews.first['id'] as int;
          }
        });
      }
    } catch (e) {
      // Error loading all crews
    }
  }

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildProblemCard(ProblemWithDetails problem) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isExpanded = _expandedProblems.contains(problem.id);
    final status = _getProblemStatus(problem);

    // Load missing symptom data if needed
    if (problem.symptom == null && problem.symptomId != 0) {
      _loadMissingSymptomData(problem);
    }

    // Load missing originator data if needed
    if (problem.originator == null && problem.originatorId.isNotEmpty) {
      _loadMissingOriginatorData(problem);
    }

    // Load missing resolver data if needed
    if (problem.actionBy == null && problem.actionById != null) {
      _loadMissingResolverData(problem);
    }

    return Card(
      child: InkWell(
        onTap: () => _toggleProblemExpansion(problem.id),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: isExpanded ? _buildExpandedProblem(problem, status, currentUserId) : _buildCollapsedProblem(problem, status),
        ),
      ),
    );
  }

  Widget _buildCollapsedProblem(ProblemWithDetails problem, String status) {
    final responders = _responders[problem.id] ?? [];
    final responderCount = responders.length;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _getStatusIndicator(status),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Strip ${problem.strip}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Problem: ${problem.symptomString ?? 'Unknown'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reported by ${problem.originatorName ?? 'Unknown'} ${_formatTime(problem.startDateTime)}',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (responderCount > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      responderCount == 1 
                        ? '• 1 crew responding'
                        : '• $responderCount crew responding',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _toggleProblemExpansion(problem.id),
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

  Widget _buildExpandedProblem(ProblemWithDetails problem, String status, String? currentUserId) {
    final isUserResponding = _responders[problem.id]?.any((r) => r['user_id'] == currentUserId) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _getStatusIndicator(status),
            const SizedBox(width: 8),
            SizedBox(
              width: 80, // Fixed width for strip text
              child: Text(
                'Strip ${problem.strip}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!_isReferee && problem.actionString == null && !problem.isResolved) ...[
              if (!isUserResponding)
                ElevatedButton(
                  onPressed: () => _goOnMyWay(problem.id),
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
                onPressed: () => _showResolveDialog(problem.id),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Resolve'),
              ),
            ],
            const Spacer(),
            IconButton(
              onPressed: () => _toggleProblemExpansion(problem.id),
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
          'Problem: ${problem.symptomString ?? 'Unknown'}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (problem.actionString != null) ...[
          const SizedBox(height: 4),
          Text('Resolution: ${problem.actionString}'),
        ],
        if (problem.notes?.isNotEmpty ?? false) ...[
          const SizedBox(height: 4),
          Text('Notes: ${problem.notes}'),
        ],
        if (problem.isResolved && problem.actionByName != null) ...[
          const SizedBox(height: 4),
          Text(
            'Resolved by: ${problem.actionByName}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ],
        const SizedBox(height: 4),
        ...[
          ProblemChat(
            messages: problem.messages,
            problemId: problem.id,
            crewId: problem.crewId,
            originator: problem.originatorName ?? 'Unknown',
            currentUserId: currentUserId,
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Reported by ${problem.originatorName ?? 'Unknown'} ${_formatTime(problem.startDateTime)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (problem.isResolved && problem.actionByName != null) ...[
          const SizedBox(height: 1),
          Text(
            'Resolved by ${problem.actionByName ?? 'Unknown'} ${_formatTime(problem.resolvedDateTimeParsed!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Future<void> _loadMissingOriginatorData(ProblemWithDetails problem) async {
    if (problem.originator != null) return; // Already has originator data
    
    try {
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('supabase_id, firstname, lastname')
          .eq('supabase_id', problem.originatorId)
          .maybeSingle();
      
      if (userResponse != null) {
        setState(() {
          final problemIndex = _problems.indexWhere((p) => p.id == problem.id);
          if (problemIndex != -1) {
            final updatedProblem = _problems[problemIndex].copyWith(
              originator: userResponse,
            );
            _problems[problemIndex] = updatedProblem;
          }
        });
      }
    } catch (e) {
      // Error loading originator data
    }
  }

  Future<void> _loadMissingResolverData(ProblemWithDetails problem) async {
    if (problem.actionBy != null || problem.actionById == null) return; // Already has resolver data or no resolver
    
    try {
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('supabase_id, firstname, lastname')
          .eq('supabase_id', problem.actionById!)
          .maybeSingle();
      
      if (userResponse != null) {
        setState(() {
          final problemIndex = _problems.indexWhere((p) => p.id == problem.id);
          if (problemIndex != -1) {
            final updatedProblem = _problems[problemIndex].copyWith(
              actionBy: userResponse,
            );
            _problems[problemIndex] = updatedProblem;
          }
        });
      }
    } catch (e) {
      // Error loading resolver data
    }
  }

  Future<void> _loadResponders() async {
    try {
      if (_problems.isEmpty) return;
      
      final problemIds = _problems.map((p) => p.id).toList();
      final response = await Supabase.instance.client
          .from('responders')
          .select('problem, user_id, responded_at')
          .inFilter('problem', problemIds);
      
      if (mounted) {
        final respondersMap = <int, List<Map<String, dynamic>>>{};
        for (final responder in response) {
          final problemId = responder['problem'] as int;
          if (!respondersMap.containsKey(problemId)) {
            respondersMap[problemId] = [];
          }
          respondersMap[problemId]!.add(responder);
        }
        setState(() {
          _responders = respondersMap;
        });
      }
    } catch (e) {
      // Error loading responders
    }
  }

  Future<void> _goOnMyWay(int problemId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      // Get problem details for notification
      final problemResponse = await Supabase.instance.client
          .from('problem')
          .select('crew, strip')
          .eq('id', problemId)
          .single();

      // Get responder name
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('firstname, lastname')
          .eq('supabase_id', userId)
          .single();
      
      await Supabase.instance.client.from('responders').insert({
        'problem': problemId,
        'user_id': userId,
        'responded_at': DateTime.now().toUtc().toIso8601String(),
      });
      
      // Update the local responders data immediately
      if (mounted) {
        setState(() {
          if (!_responders.containsKey(problemId)) {
            _responders[problemId] = [];
          }
          _responders[problemId]!.add({
            'problem': problemId,
            'user_id': userId,
            'responded_at': DateTime.now().toUtc().toIso8601String(),
          });
        });
      }
      
      // Also reload from database to ensure consistency
      await _loadResponders();
      
      // Send notification using Edge Function
      final responderName = '${userResponse['firstname']} ${userResponse['lastname']}';
      final strip = problemResponse['strip'] as String;
      final crewId = problemResponse['crew'].toString();

      await NotificationService().sendCrewNotification(
        title: 'Crew Member En Route',
        body: '$responderName is en route to Strip $strip',
        crewId: crewId,
        senderId: userId,
        data: {
          'type': 'problem_response',
          'problemId': problemId.toString(),
          'crewId': crewId,
          'strip': strip,
        },
        includeReporter: false, // Don't include responder for "on my way" notifications
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are now en route')),
        );
      }
    } catch (e) {
      if (mounted) {
        // Check if it's a duplicate key error
        if (e.toString().contains('duplicate key') || e.toString().contains('UNIQUE')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are already en route')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update status: $e')),
          );
        }
      }
    }
  }

  void _toggleProblemExpansion(int problemId) {
    setState(() {
      if (_expandedProblems.contains(problemId)) {
        _expandedProblems.remove(problemId);
      } else {
        _expandedProblems.add(problemId);
      }
    });
  }

  String _getProblemStatus(ProblemWithDetails problem) {
    if (problem.isResolved) return 'resolved';
    if (_responders.containsKey(problem.id) && _responders[problem.id]!.isNotEmpty) {
      return 'en_route';
    }
    return 'new';
  }

  Widget _getStatusIndicator(String status) {
    switch (status) {
      case 'new':
        return Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
        );
      case 'en_route':
        return Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
        );
      case 'resolved':
        return Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle;
    if (_isSuperUser) {
      final selectedCrew = _allCrews.firstWhere(
        (crew) => crew['id'] == _selectedCrewId,
        orElse: () => {'crewtype': {'crewtype': 'All Crews'}},
      );
      final crewType = selectedCrew['crewtype']?['crewtype'] ?? 'All Crews';
      appBarTitle = crewType;
    } else {
      appBarTitle = _userCrewName ?? 'My Problems';
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSuperUser 
          ? DropdownButton<int>(
              value: _selectedCrewId,
              underline: Container(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              items: _allCrews.map((crew) {
                final crewType = crew['crewtype']?['crewtype'] ?? 'Unknown';
                return DropdownMenuItem(
                  value: crew['id'] as int,
                  child: Text(crewType),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCrewId = value;
                });
                _loadProblems();
              },
            )
          : Text(appBarTitle),
        actions: [
          const SettingsMenu(),
        ],
      ),
      body: Column(
        children: [
          // Crew Message Window (only show for crew members, not referees)
          if (!_isReferee && widget.crewId != null)
            CrewMessageWindow(
              crewId: widget.crewId!,
              currentUserId: Supabase.instance.client.auth.currentUser?.id,
            ),
          // Problems List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _error!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _problems.isEmpty
                        ? Center(
                            child: Text(_isReferee 
                              ? 'You haven\'t reported any problems yet'
                              : 'No problems reported yet'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _problems.length,
                            itemBuilder: (context, index) {
                              final problem = _problems[index];
                              final isUserCrew = _userCrewId != null && problem.crewId == _userCrewId;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Stack(
                                  children: [
                                    Card(
                                      child: _buildProblemCard(problem),
                                    ),
                                    if (!isUserCrew)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.secondary,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Other Crew',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewProblemDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
} 