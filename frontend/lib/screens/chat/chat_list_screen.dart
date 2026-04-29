import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/themes/color_palette.dart';
import '../../models/conversation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/test_chat_provider.dart';
import 'chat_detail_screen.dart';
import 'new_message_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final chatProvider = Provider.of<TestChatProvider>(context, listen: false);
    await chatProvider.loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<TestChatProvider>(context);
    final currentUserId = authProvider.user?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: ColorPalette.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'New message',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NewMessageScreen(),
                ),
              ).then((_) => _loadData());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (chatProvider.totalUnread > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: ColorPalette.primaryGreen.withOpacity(0.1),
              child: Text(
                '${chatProvider.totalUnread} unread message${chatProvider.totalUnread > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: ColorPalette.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _buildBody(
                context: context,
                chatProvider: chatProvider,
                currentUserId: currentUserId,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NewMessageScreen(),
            ),
          ).then((_) => _loadData());
        },
        backgroundColor: ColorPalette.primaryGreen,
        child: const Icon(Icons.message, color: Colors.white),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required TestChatProvider chatProvider,
    required String currentUserId,
  }) {
    if (chatProvider.isLoading && chatProvider.conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 320,
            child: Center(
              child: CircularProgressIndicator(
                color: ColorPalette.primaryGreen,
              ),
            ),
          ),
        ],
      );
    }

    if (chatProvider.error != null && chatProvider.conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.error_outline,
            size: 72,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'Unable to load messages',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            chatProvider.error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorPalette.primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    if (chatProvider.conversations.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: chatProvider.conversations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final conversation = chatProvider.conversations[index];
        return _ConversationCard(
          conversation: conversation,
          currentUserId: currentUserId,
          onTap: () async {
            await chatProvider.markConversationAsRead(conversation.id);
            chatProvider.selectConversation(conversation.id);
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatDetailScreen(
                  conversationId: conversation.id,
                  conversation: conversation,
                ),
              ),
            ).then((_) {
              chatProvider.selectConversation('');
              chatProvider.loadUnreadCounts();
            });
          },
          onDelete: () => _showDeleteDialog(context, conversation.id),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 420,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a conversation with a vendor or admin',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NewMessageScreen(),
                      ),
                    ).then((_) => _loadData());
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorPalette.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    String conversationId,
  ) async {
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text(
          'Are you sure you want to delete this conversation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final chatProvider = Provider.of<TestChatProvider>(
                context,
                listen: false,
              );
              await chatProvider.deleteConversation(conversationId);
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

class _ConversationCard extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationCard({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
    required this.onDelete,
  });

  Participant? get _otherParticipant {
    for (final participant in conversation.participants) {
      if (participant.userId != currentUserId) {
        return participant;
      }
    }
    return conversation.participants.isNotEmpty
        ? conversation.participants.first
        : null;
  }

  String get _displayName {
    return _otherParticipant?.fullName.trim().isNotEmpty == true
        ? _otherParticipant!.fullName.trim()
        : 'Unknown User';
  }

  String get _roleLabel {
    final role = _otherParticipant?.role.toLowerCase() ?? 'user';
    switch (role) {
      case 'vendor':
        return 'Vendor';
      case 'admin':
        return 'Admin';
      case 'tourist':
        return 'Tourist';
      default:
        return 'User';
    }
  }

  String get _previewText {
    final text = conversation.lastMessage?.content.trim();
    if (text == null || text.isEmpty) {
      return conversation.listingTitle?.trim().isNotEmpty == true
          ? 'Regarding ${conversation.listingTitle}'
          : 'Open conversation';
    }
    return text;
  }

  String get _timeLabel {
    final sentAt = conversation.lastMessage?.sentAt ?? conversation.updatedAt;
    final diff = DateTime.now().difference(sentAt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  Color get _accentColor {
    switch ((_otherParticipant?.role ?? '').toLowerCase()) {
      case 'vendor':
        return Colors.blue;
      case 'admin':
        return Colors.deepPurple;
      case 'tourist':
        return ColorPalette.primaryGreen;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: ColorPalette.primaryGreen.withOpacity(0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _accentColor.withOpacity(0.12),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: _accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _timeLabel,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _accentColor.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _roleLabel,
                              style: TextStyle(
                                color: _accentColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if ((conversation.listingTitle ?? '').trim().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                conversation.listingTitle!.trim(),
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _previewText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                      child: Icon(
                        Icons.more_vert,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (conversation.unreadCount > 0)
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: const BoxDecoration(
                          color: ColorPalette.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            conversation.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
