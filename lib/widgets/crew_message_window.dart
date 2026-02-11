import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/crew_message.dart';
import '../services/notification_service.dart';
import '../utils/debug_utils.dart';
import '../theme/theme.dart';
import 'adaptive/adaptive.dart';

class CrewMessageWindow extends StatefulWidget {
  final int crewId;
  final String? currentUserId;

  const CrewMessageWindow({
    super.key,
    required this.crewId,
    required this.currentUserId,
  });

  @override
  CrewMessageWindowState createState() => CrewMessageWindowState();
}

class CrewMessageWindowState extends State<CrewMessageWindow> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<CrewMessage> _messages = [];
  bool _isLoading = true;
  bool _isExpanded = false;
  Set<int> _readMessageIds = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadReadMessageIds();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Public method to check for new messages. Called by parent's update timer.
  Future<void> checkForNewMessages() async {
    await _checkForNewMessages();
  }

  Future<void> _loadReadMessageIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds =
          prefs.getStringList('read_crew_messages_${widget.crewId}') ?? [];
      if (mounted) {
        setState(() {
          _readMessageIds = readIds.map((id) => int.parse(id)).toList().toSet();
        });
      }
    } catch (e) {
      debugLogError('Error loading read message IDs', e);
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
      debugLogError('Error marking messages as read', e);
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
          _messages = response
              .map((json) => CrewMessage.fromJson(json))
              .toList();
          _isLoading = false;
        });
        _scrollToBottom();
        _markMessagesAsRead(); // Mark messages as read when viewed
      }
    } catch (e) {
      debugLogError('Error loading messages', e);
      setState(() {
        _isLoading = false;
      });
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
        final newMessages = response
            .map((json) => CrewMessage.fromJson(json))
            .toList();
        setState(() {
          // Filter out duplicates based on message ID
          final existingIds = _messages.map((m) => m.id).toSet();
          final uniqueNewMessages = newMessages
              .where((m) => !existingIds.contains(m.id))
              .toList();

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
      debugLogError('Error checking for new crew messages', e);
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

      try {
        await Supabase.instance.client.from('crew_messages').insert(insertData);
      } catch (insertError) {
        debugLogError('Error inserting crew message', insertError);
        rethrow;
      }

      // Clear the input immediately
      if (mounted) {
        setState(() {
          _messageController.clear();
        });
      }

      // Reload messages to get the new one with all data
      try {
        await _loadMessages();
      } catch (loadError) {
        debugLogError('Error loading messages after insert', loadError);
      }

      // Send notification for the new message
      try {
        await NotificationService().sendCrewNotification(
          title: 'Crew Message',
          body: message.length > 50
              ? '${message.substring(0, 50)}...'
              : message,
          crewId: widget.crewId.toString(),
          senderId: widget.currentUserId!,
          data: {'type': 'crew_message', 'crewId': widget.crewId.toString()},
          includeReporter: false,
        );
      } catch (notifError) {
        debugLogError('Error sending notification', notifError);
      }
    } catch (e) {
      debugLogError('Error sending message', e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
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
    return _messages
        .where((message) => !_readMessageIds.contains(message.id))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: AppSpacing.paddingSm,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with expand/collapse
          AppListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Crew Messages'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_getUnreadCount() > 0)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary(context),
                      borderRadius: AppSpacing.borderRadiusLg,
                    ),
                    child: Text(
                      _getUnreadCount().toString(),
                      style: AppTypography.badge(
                        context,
                      ).copyWith(color: AppColors.onPrimary(context)),
                    ),
                  ),
                AppSpacing.horizontalSm,
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
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
          // Show last message when collapsed (for context)
          if (!_isExpanded && _messages.isNotEmpty)
            Padding(
              padding: AppSpacing.paddingHorizontalMd,
              child: Container(
                width: double.infinity,
                padding: AppSpacing.paddingSm,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow(context),
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
                child: Text(
                  '${_messages.first.authorName ?? 'Unknown'}: ${_messages.first.message}',
                  style: AppTypography.bodySmall(
                    context,
                  ).copyWith(color: AppColors.textSecondary(context)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          // Message input
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _messageController,
                    hint: 'Type a crew message...',
                    maxLines: 1,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                AppSpacing.horizontalSm,
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    foregroundColor: AppColors.onPrimary(context),
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
                  top: BorderSide(color: AppColors.divider(context)),
                ),
              ),
              child: _isLoading
                  ? const Center(child: AppLoadingIndicator())
                  : _messages.isEmpty
                  ? Padding(
                      padding: AppSpacing.paddingMd,
                      child: Text(
                        'No crew messages yet',
                        style: AppTypography.bodyMedium(
                          context,
                        ).copyWith(color: AppColors.textSecondary(context)),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: AppSpacing.paddingSm,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message.authorId == widget.currentUserId;

                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe) ...[
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: AppColors.primary(context),
                                  child: Text(
                                    message.authorName
                                            ?.substring(0, 1)
                                            .toUpperCase() ??
                                        '?',
                                    style: AppTypography.labelSmall(context)
                                        .copyWith(
                                          color: AppColors.onPrimary(context),
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                                AppSpacing.horizontalSm,
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
                                        style: AppTypography.chatSenderName(
                                          context,
                                        ),
                                      ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm + 4,
                                        vertical: AppSpacing.sm - 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? AppColors.chatBubbleSelf(context)
                                            : AppColors.chatBubbleOther(
                                                context,
                                              ),
                                        borderRadius: AppSpacing.borderRadiusLg,
                                      ),
                                      child: Text(
                                        message.message,
                                        style:
                                            AppTypography.chatMessage(
                                              context,
                                            ).copyWith(
                                              color: isMe
                                                  ? AppColors.chatBubbleSelfText(
                                                      context,
                                                    )
                                                  : AppColors.chatBubbleOtherText(
                                                      context,
                                                    ),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatTime(message.createdAt),
                                      style: AppTypography.timestamp(context),
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
