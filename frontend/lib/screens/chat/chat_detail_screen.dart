import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/themes/color_palette.dart';
import '../../models/conversation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/test_chat_provider.dart';

class ChatDetailScreen extends StatefulWidget {
  final String conversationId;
  final dynamic conversation;

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    required this.conversation,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isTyping = false;
  Timer? _typingStartTimer;
  Timer? _typingStopTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _typingStartTimer?.cancel();
    _typingStopTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final chatProvider = Provider.of<TestChatProvider>(context, listen: false);
    await chatProvider.loadMessages(widget.conversationId);
    await chatProvider.markConversationAsRead(widget.conversationId);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getCurrentUserId() {
    return Provider.of<AuthProvider>(context, listen: false).user?.id ?? '';
  }

  void _handleTyping(String text) {
    final chatProvider = Provider.of<TestChatProvider>(context, listen: false);
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      _typingStartTimer?.cancel();
      _typingStopTimer?.cancel();
      if (_isTyping) {
        setState(() => _isTyping = false);
        chatProvider.sendTyping(widget.conversationId, false);
      }
      return;
    }

    if (!_isTyping) {
      _typingStartTimer?.cancel();
      _typingStartTimer = Timer(const Duration(milliseconds: 350), () {
        if (!mounted || _messageController.text.trim().isEmpty || _isTyping) {
          return;
        }
        setState(() => _isTyping = true);
        chatProvider.sendTyping(widget.conversationId, true);
      });
    }

    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted || !_isTyping) {
        return;
      }
      setState(() => _isTyping = false);
      chatProvider.sendTyping(widget.conversationId, false);
    });
  }

  bool _shouldShowTypingIndicator(
    TestChatProvider chatProvider,
    Participant? otherParticipant,
  ) {
    if (_isTyping || otherParticipant == null || otherParticipant.userId.isEmpty) {
      return false;
    }

    return chatProvider.typingUsers[otherParticipant.userId] ?? false;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    final chatProvider = Provider.of<TestChatProvider>(context, listen: false);

    if (_isTyping) {
      setState(() => _isTyping = false);
      chatProvider.sendTyping(widget.conversationId, false);
    }
    _typingStartTimer?.cancel();
    _typingStopTimer?.cancel();

    await chatProvider.sendMessage(
      conversationId: widget.conversationId,
      content: text,
    );

    if (mounted) {
      setState(() {});
    }
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null || !mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image selected: ${image.name}'),
          duration: const Duration(seconds: 1),
        ),
      );

      final chatProvider = Provider.of<TestChatProvider>(context, listen: false);
      await chatProvider.sendMessage(
        conversationId: widget.conversationId,
        content: 'Image shared',
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _pickDocument() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document sharing coming soon'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Participant? _getOtherParticipant() {
    final currentUserId = _getCurrentUserId();
    try {
      return widget.conversation.participants.firstWhere(
        (p) => p.userId != currentUserId,
      );
    } catch (_) {
      return widget.conversation.participants.isNotEmpty
          ? widget.conversation.participants.first
          : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<TestChatProvider>(context);
    final currentUserId = _getCurrentUserId();
    final messages = chatProvider.getMessages(widget.conversationId);
    final otherParticipant = _getOtherParticipant();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              otherParticipant?.fullName ?? 'Chat',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (otherParticipant != null)
              Text(
                _getRoleDisplay(otherParticipant.role),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: ColorPalette.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              await _loadMessages();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat refreshed')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (sheetContext) => SafeArea(
                  child: Wrap(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.delete),
                        title: const Text('Delete Conversation'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _showDeleteDialog();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadMessages,
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;
                    return _buildMessageBubble(message, isMe);
                  },
                ),
              ),
            ),
          ),
          if (_shouldShowTypingIndicator(chatProvider, otherParticipant))
            _buildTypingIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(dynamic message, bool isMe) {
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isMe ? ColorPalette.primaryGreen : Colors.grey.shade100;
    final textColor = isMe ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _getRoleColor(message.senderRole),
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.content.startsWith('Image shared'))
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 200,
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(Icons.image, size: 40),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message.content,
                              style: TextStyle(color: textColor),
                            ),
                          ],
                        )
                      else
                        Text(
                          message.content,
                          style: TextStyle(color: textColor),
                        ),
                    ],
                  ),
                ),
              ),
              if (isMe) const SizedBox(width: 8),
            ],
          ),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    message.status == 'read' ? Icons.done_all : Icons.check,
                    size: 12,
                    color: message.status == 'read'
                        ? Colors.blue
                        : Colors.grey.shade500,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'vendor':
        return Colors.blue;
      case 'tourist':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplay(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrator';
      case 'vendor':
        return 'Service Provider';
      case 'tourist':
        return 'Traveler';
      default:
        return role;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    }
    if (difference.inDays < 1) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.day}/${time.month}';
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  AlwaysStoppedAnimation<Color>(ColorPalette.primaryGreen),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Typing...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (sheetContext) => SafeArea(
                  child: Wrap(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.image),
                        title: const Text('Image'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickImage();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.description),
                        title: const Text('Document'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickDocument();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              onChanged: (text) {
                _handleTyping(text);
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          if (_messageController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.send),
              color: ColorPalette.primaryGreen,
              onPressed: _sendMessage,
            ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text('Are you sure you want to delete this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final chatProvider =
                  Provider.of<TestChatProvider>(context, listen: false);
              await chatProvider.deleteConversation(widget.conversationId);
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Conversation deleted')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
