import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  bool _includeReporter = false;
  final Map<String, String> _userNameCache = {};
  String? _crewDisplayStyle;
  List<Map<String, dynamic>> _messages = [];
  String? _error;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadCrewDisplayStyle();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      debugLog('Loading messages for problem ${widget.problemId}');
      final messages = await Supabase.instance.client
          .from('messages')
          .select('*')
          .eq('problem', widget.problemId)
          .order('created_at', ascending: true);
      
      debugLog('Found ${messages.length} messages for problem ${widget.problemId}');
      
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(messages);
        });
        debugLog('Updated messages state with ${_messages.length} messages');
      }
    } catch (e) {
      debugLogError('Error loading messages', e);
      setState(() {
        _error = 'Failed to load messages: $e';
        _isLoading = false;
      });
    }
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