import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'message_bubble.dart';
import '../services/notification_service.dart';
import '../utils/debug_utils.dart';

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
  final ScrollController _scrollController = ScrollController();
  bool _includeReporter = true; // Default to true for non-crew reporters
  final Map<String, String> _userNameCache = {};
  String? _crewDisplayStyle;
  List<Map<String, dynamic>> _messages = [];
  String? _error;
  bool _isLoading = false;
  bool _isCrewMember = false;
  bool _isSuperUser = false;

  @override
  void initState() {
    super.initState();
    _loadCrewDisplayStyle();
    _loadMessages();
    // Don't poll here - the problems page handles updates centrally
  }

  @override
  void didUpdateWidget(ProblemChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload messages when the widget rebuilds (due to parent refresh)
    if (oldWidget.problemId == widget.problemId) {
      _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    try {
      // debugLog('Loading messages for problem ${widget.problemId}');
      final messages = await Supabase.instance.client
          .from('messages')
          .select('*')
          .eq('problem', widget.problemId)
          .order('created_at', ascending: true);

      // debugLog('Found ${messages.length} messages for problem ${widget.problemId}');

      // Check if current user is a crew member
      bool isCrewMember = false;
      try {
        final crewCheck = await Supabase.instance.client
            .from('crewmembers')
            .select('crew')
            .eq('crew', widget.crewId)
            .eq('crewmember', widget.currentUserId!)
            .maybeSingle();
        isCrewMember = crewCheck != null;
      } catch (e) {
        debugLogError('Error checking crew membership', e);
      }

      // Check if user is a superuser
      bool isSuperUser = false;
      try {
        final userCheck = await Supabase.instance.client
            .from('users')
            .select('superuser')
            .eq('supabase_id', widget.currentUserId!)
            .maybeSingle();
        isSuperUser = userCheck?['superuser'] == true;
      } catch (e) {
        debugLogError('Error checking superuser status', e);
      }

      // Filter messages: crew members and superusers see all, non-crew only see messages with include_reporter=true
      final filteredMessages = messages.where((msg) {
        if (isCrewMember || isSuperUser) {
          return true; // Crew members and superusers see all messages
        }
        // Non-crew members (reporters not on crew) see messages marked for them OR messages they authored
        final includeReporter = msg['include_reporter'];
        final isAuthor = msg['author'] == widget.currentUserId;
        return isAuthor || includeReporter == null || includeReporter == true;
      }).toList();

      // debugLog('Filtered to ${filteredMessages.length} messages (isCrewMember: $isCrewMember)');

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(filteredMessages);
          _isCrewMember = isCrewMember;
          _isSuperUser = isSuperUser;
        });
        // debugLog('Updated messages state with ${_messages.length} messages');
        // Scroll to bottom after messages are loaded
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      debugLogError('Error loading messages', e);
      setState(() {
        _error = 'Failed to load messages: $e';
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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
            border: Border.all(color: Colors.grey.shade400, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: _messages.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No messages yet'),
                )
              : ListView.builder(
                  controller: _scrollController,
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
                  await Supabase.instance.client.from('messages').insert(insertData);
                  if (!mounted) return;

                  // Reload all messages with filtering
                  await _loadMessages();

                  if (mounted) {
                    setState(() {
                      _messageController.clear();
                    });
                  }

                  // Send notification for the new message (skip on web to avoid type errors)
                  if (!kIsWeb) {
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
                      includeReporter: _includeReporter,
                      reporterId: widget.originator?.toString(), // Pass the reporter ID
                    );
                  }

                  messenger.showSnackBar(
                    const SnackBar(content: Text('Message sent')),
                  );
                } catch (e) {
                  debugLogError('Error sending message', e);
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to send message: $e')),
                  );
                }
              },
            ),
          ],
        ),
        // Only show checkbox for crew members and superusers
        if (_isCrewMember || _isSuperUser)
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
