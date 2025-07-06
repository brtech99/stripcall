import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/crew_message.dart';
import '../services/notification_service.dart';

class CrewMessageWindow extends StatefulWidget {
  final int crewId;
  final String? currentUserId;

  const CrewMessageWindow({
    super.key,
    required this.crewId,
    required this.currentUserId,
  });

  @override
  State<CrewMessageWindow> createState() => _CrewMessageWindowState();
}

class _CrewMessageWindowState extends State<CrewMessageWindow> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<CrewMessage> _messages = [];
  bool _isLoading = true;
  bool _isExpanded = false;
  Timer? _updateTimer;
  // Removed unused field: _userNameCache
  Set<int> _readMessageIds = {}; // Track which messages the user has seen

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startUpdateTimer();
    _loadReadMessageIds();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _checkForNewMessages();
      }
    });
  }

  Future<void> _loadReadMessageIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList('read_crew_messages_${widget.crewId}') ?? [];
      if (mounted) {
        setState(() {
          _readMessageIds = readIds.map((id) => int.parse(id)).toList().toSet();
        });
      }
    } catch (e) {
      // Error loading read message IDs
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds = _messages.map((msg) => msg.id.toString()).toList();
      await prefs.setStringList('read_crew_messages_${widget.crewId}', readIds);
      if (mounted) {
        setState(() {
          _readMessageIds = _messages.map((msg) => msg.id).toSet();
        });
      }
    } catch (e) {
      // Error marking messages as read
    }
  }

  Future<void> _loadMessages() async {
    try {
      final response = await Supabase.instance.client
          .from('crew_messages')
          .select('''
            *,
            author_data:author(supabase_id, firstname, lastname)
          ''')
          .eq('crew', widget.crewId)
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _messages = response.map((json) => CrewMessage.fromJson(json)).toList();
          _isLoading = false;
        });
        _scrollToBottom();
        _markMessagesAsRead(); // Mark messages as read when viewed
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      // Error loading crew messages
    }
  }

  Future<void> _checkForNewMessages() async {
    if (_messages.isEmpty) return;

    try {
      final latestMessageTime = _messages.first.createdAt;
      final response = await Supabase.instance.client
          .from('crew_messages')
          .select('''
            *,
            author_data:author(supabase_id, firstname, lastname)
          ''')
          .eq('crew', widget.crewId)
          .gt('created_at', latestMessageTime.toIso8601String())
          .order('created_at', ascending: false);

      if (mounted && response.isNotEmpty) {
        final newMessages = response.map((json) => CrewMessage.fromJson(json)).toList();
        setState(() {
          // Filter out duplicates based on message ID
          final existingIds = _messages.map((m) => m.id).toSet();
          final uniqueNewMessages = newMessages.where((m) => !existingIds.contains(m.id)).toList();
          
          if (uniqueNewMessages.isNotEmpty) {
            _messages.insertAll(0, uniqueNewMessages);
            // Keep only the last 20 messages to prevent memory issues
            if (_messages.length > 20) {
              _messages = _messages.take(20).toList();
            }
            _markMessagesAsRead(); // Mark new messages as read
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      // Error checking for new crew messages
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

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || widget.currentUserId == null) return;

    try {
      final insertData = {
        'crew': widget.crewId,
        'author': widget.currentUserId,
        'message': message,
      };

      final result = await Supabase.instance.client
          .from('crew_messages')
          .insert(insertData)
          .select('''
            *,
            author_data:author(supabase_id, firstname, lastname)
          ''')
          .single();

      if (mounted) {
        setState(() {
          _messageController.clear();
          final newMessage = CrewMessage.fromJson(result);
          
          // Check if this message already exists to prevent duplicates
          final messageExists = _messages.any((m) => m.id == newMessage.id);
          if (!messageExists) {
            _messages.add(newMessage);
            // Keep only the last 20 messages
            if (_messages.length > 20) {
              _messages = _messages.take(20).toList();
            }
          }
        });
        _scrollToBottom();
      }

      // Send notification for the new message
      await NotificationService().sendCrewNotification(
        title: 'Crew Message',
        body: message.length > 50 ? '${message.substring(0, 50)}...' : message,
        crewId: widget.crewId.toString(),
        senderId: widget.currentUserId!,
        data: {
          'type': 'crew_message',
          'crewId': widget.crewId.toString(),
        },
        includeReporter: false,
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int _getUnreadCount() {
    return _messages.where((message) => !_readMessageIds.contains(message.id)).length;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with expand/collapse
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Crew Messages'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_getUnreadCount() > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getUnreadCount().toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    final willExpand = !_isExpanded;
                    setState(() {
                      _isExpanded = willExpand;
                    });
                    if (willExpand) {
                      _markMessagesAsRead(); // Mark messages as read when expanding
                    }
                  },
                ),
              ],
            ),
          ),
          // Message input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a crew message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    maxLines: 1,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Messages area (only shown when expanded)
          if (_isExpanded) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No crew messages yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe = message.authorId == widget.currentUserId;
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe) ...[
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      child: Text(
                                        message.authorName?.substring(0, 1).toUpperCase() ?? '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: isMe 
                                          ? CrossAxisAlignment.end 
                                          : CrossAxisAlignment.start,
                                      children: [
                                        if (!isMe)
                                          Text(
                                            message.authorName ?? 'Unknown',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isMe 
                                                ? Theme.of(context).colorScheme.primary
                                                : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            message.message,
                                            style: TextStyle(
                                              color: isMe 
                                                  ? Colors.white 
                                                  : null,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatTime(message.createdAt),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ],
      ),
    );
  }
} 