import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_manager.dart';
import '../services/chat_service.dart';
import '../models/crew_message.dart';
import '../services/notification_service.dart';
import '../utils/debug_utils.dart';
import '../theme/theme.dart';
import 'adaptive/adaptive.dart';
import 'message_bubble.dart';

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
  final ChatService _chatService = ChatService();
  List<CrewMessage> _messages = [];
  bool _isLoading = true;
  bool _isExpanded = false;
  bool _isSending = false;
  Set<int> _readMessageIds = {};
  String? _crewDisplayStyle;

  @override
  void initState() {
    super.initState();
    _loadCrewDisplayStyle();
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

  Future<void> _loadCrewDisplayStyle() async {
    final displayStyle = await _chatService.loadCrewDisplayStyle(widget.crewId);
    if (mounted && displayStyle != null) {
      setState(() {
        _crewDisplayStyle = displayStyle;
      });
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
      final response = await SupabaseManager()
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
          // Query fetches newest 10, reverse to display oldest-on-top
          _messages = response
              .map((json) => CrewMessage.fromJson(json))
              .toList()
              .reversed
              .toList();
          _isLoading = false;
        });
        _scrollToBottom();
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
      final latestMessageTime = _messages.last.createdAt;
      final response = await SupabaseManager()
          .from('crew_messages')
          .select('''
            *,
            author_data:author(supabase_id, firstname, lastname)
          ''')
          .eq('crew', widget.crewId)
          .gt('created_at', latestMessageTime.toIso8601String())
          .order('created_at', ascending: true);

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
            _messages.addAll(uniqueNewMessages);
            // Keep only the last 20 messages to prevent memory issues
            if (_messages.length > 20) {
              _messages = _messages.sublist(_messages.length - 20);
            }
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

  Widget _buildSendButton() {
    final accentColor = AppColors.actionAccent(context);

    if (_isSending) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: accentColor,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _sendMessage,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: accentColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.send, size: 16, color: Colors.white),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || widget.currentUserId == null || _isSending) return;

    setState(() => _isSending = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await SupabaseManager().dualInsert('crew_messages', {
        'crew': widget.crewId,
        'author': widget.currentUserId,
        'message': message,
      });

      if (!mounted) return;
      _messageController.clear();
      await _loadMessages();

      messenger.showSnackBar(const SnackBar(content: Text('Message sent')));

      // Send notification (fire and forget)
      NotificationService().sendCrewNotification(
        title: 'Crew Message',
        body: message.length > 50
            ? '${message.substring(0, 50)}...'
            : message,
        crewId: widget.crewId.toString(),
        senderId: widget.currentUserId!,
        data: {'type': 'crew_message', 'crewId': widget.crewId.toString()},
        includeReporter: false,
      ).catchError((e) {
        debugLogError('Error sending notification', e);
        return false;
      });
    } catch (e) {
      debugLogError('Error sending message', e);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
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
                      color: AppColors.unreadBadge,
                      borderRadius: AppSpacing.borderRadiusLg,
                    ),
                    child: Text(
                      _getUnreadCount().toString(),
                      style: AppTypography.badge(
                        context,
                      ).copyWith(color: Colors.white),
                    ),
                  ),
                AppSpacing.horizontalSm,
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () {
                    final wasExpanded = _isExpanded;
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                    // Mark messages as read when expanding (viewing) or collapsing
                    _markMessagesAsRead();
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
                  '${_messages.last.authorName ?? 'Unknown'}: ${_messages.last.message}',
                  style: AppTypography.bodySmall(
                    context,
                  ).copyWith(color: AppColors.textSecondary(context)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
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
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message.authorId == widget.currentUserId;
                        return MessageBubble(
                          text: message.message,
                          senderName: message.authorName ?? 'Unknown',
                          isMe: isMe,
                          createdAt: message.createdAt,
                          displayStyle: _crewDisplayStyle,
                        );
                      },
                    ),
            ),
            // Message input (only when expanded)
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
                      hint: 'Type a message...',
                      maxLines: 1,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  AppSpacing.horizontalSm,
                  _buildSendButton(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
