import 'package:flutter/material.dart';
import 'message_bubble.dart';
import '../services/chat_service.dart';
import '../utils/debug_utils.dart';
import '../theme/theme.dart';
import 'adaptive/adaptive.dart';

class ProblemChat extends StatefulWidget {
  final List<dynamic>? messages;
  final int problemId;
  final int crewId;
  final dynamic originator;
  final String? currentUserId;
  final bool isCrewMember;
  final bool isSuperUser;

  const ProblemChat({
    super.key,
    required this.messages,
    required this.problemId,
    required this.crewId,
    required this.originator,
    required this.currentUserId,
    required this.isCrewMember,
    required this.isSuperUser,
  });

  @override
  State<ProblemChat> createState() => _ProblemChatState();
}

class _ProblemChatState extends State<ProblemChat> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _includeReporter = true;
  final Map<String, String> _userNameCache = {};
  String? _crewDisplayStyle;
  List<Map<String, dynamic>> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadCrewDisplayStyle();
    _loadMessages();
  }

  @override
  void didUpdateWidget(ProblemChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload messages when the widget rebuilds (due to parent refresh)
    if (oldWidget.problemId == widget.problemId) {
      _loadMessages();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.loadMessages(
        problemId: widget.problemId,
        currentUserId: widget.currentUserId,
        isCrewMember: widget.isCrewMember,
        isSuperUser: widget.isSuperUser,
      );

      if (mounted) {
        setState(() {
          _messages = messages;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      debugLogError('Error loading messages', e);
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

  Future<String> _getUserName(String userId) async {
    // Check cache first
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }

    final name = await _chatService.getUserName(userId);
    final displayName = name ?? 'User ${userId.substring(0, 8)}...';

    if (mounted) {
      setState(() {
        _userNameCache[userId] = displayName;
      });
    }
    return displayName;
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
    final text = _messageController.text.trim();
    if (text.isEmpty || widget.currentUserId == null || _isSending) return;

    setState(() => _isSending = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _chatService.sendMessage(
        problemId: widget.problemId,
        crewId: widget.crewId,
        authorId: widget.currentUserId!,
        message: text,
        includeReporter: _includeReporter,
        reporterId: widget.originator?.toString(),
      );

      if (!mounted) return;

      _messageController.clear();
      await _loadMessages();

      messenger.showSnackBar(const SnackBar(content: Text('Message sent')));
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

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final authorId = msg['author'] as String?;
    final isMe = authorId == widget.currentUserId;
    final messageText = msg['message'] as String? ?? '';
    final createdAt = DateTime.parse(msg['created_at']);

    // Handle SMS messages (author is null)
    if (authorId == null) {
      final parsed = _chatService.parseSmsMessage(messageText);
      return MessageBubble(
        text: parsed.messageText,
        senderName: parsed.senderName,
        isMe: false,
        createdAt: createdAt,
        displayStyle: _crewDisplayStyle,
      );
    }

    return FutureBuilder<String>(
      future: _getUserName(authorId),
      builder: (context, snapshot) {
        return MessageBubble(
          text: messageText,
          senderName: snapshot.data ?? 'Loading...',
          isMe: isMe,
          createdAt: createdAt,
          displayStyle: _crewDisplayStyle,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSeeAllMessages = widget.isCrewMember || widget.isSuperUser;

    return Column(
      children: [
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outline(context), width: 1),
            borderRadius: AppSpacing.borderRadiusSm,
          ),
          child: _messages.isEmpty
              ? Padding(
                  padding: AppSpacing.paddingMd,
                  child: Text(
                    'No messages yet',
                    style: AppTypography.bodyMedium(
                      context,
                    ).copyWith(color: AppColors.textSecondary(context)),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                    horizontal: AppSpacing.xs,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, idx) =>
                      _buildMessageBubble(_messages[idx]),
                ),
        ),
        AppSpacing.verticalSm,
        Row(
          children: [
            Expanded(
              child: AppTextField(
                key: ValueKey('problem_chat_message_field_${widget.problemId}'),
                controller: _messageController,
                hint: 'Type a message...',
                maxLines: 1,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            AppSpacing.horizontalSm,
            IconButton(
              key: ValueKey('problem_chat_send_button_${widget.problemId}'),
              icon: _isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 24),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ],
        ),
        // Only show checkbox for crew members and superusers
        if (canSeeAllMessages)
          Row(
            children: [
              Checkbox(
                key: ValueKey(
                  'problem_chat_include_reporter_${widget.problemId}',
                ),
                value: _includeReporter,
                onChanged: (val) =>
                    setState(() => _includeReporter = val ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Text(
                'Include reporter',
                style: AppTypography.labelSmall(context),
              ),
            ],
          ),
      ],
    );
  }
}
