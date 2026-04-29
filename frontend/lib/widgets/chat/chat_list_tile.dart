// lib/widgets/chat/chat_list_tile.dart
import 'package:flutter/material.dart';
import '../../models/conversation.dart';
import '../../core/themes/color_palette.dart';

class ChatListTile extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ChatListTile({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
    this.onDelete,
  });

  Participant? get otherParticipant {
    try {
      return conversation.participants.firstWhere(
        (p) => p.userId != currentUserId,
      );
    } catch (e) {
      return conversation.participants.isNotEmpty 
          ? conversation.participants.first 
          : null;
    }
  }

  String get lastMessageTime {
    if (conversation.lastMessage == null) return '';
    
    final time = conversation.lastMessage!.sentAt;
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 7) {
      return '${time.day}/${time.month}/${time.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  Color get roleColor {
    if (otherParticipant == null) return Colors.grey;
    
    switch (otherParticipant!.role) {
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

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(conversation.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        onTap: onTap,
        leading: _buildAvatar(),
        title: _buildTitle(),
        subtitle: _buildSubtitle(),
        trailing: _buildTrailing(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildAvatar() {
    if (otherParticipant == null) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade200,
        child: const Icon(Icons.person, color: Colors.grey),
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: roleColor.withOpacity(0.2),
      child: Text(
        otherParticipant!.fullName.isNotEmpty
            ? otherParticipant!.fullName[0].toUpperCase()
            : '?',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: roleColor,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    if (otherParticipant == null) {
      return const Text(
        'Unknown User',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            otherParticipant!.fullName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    return Text(
      conversation.lastMessage?.content ?? 'No messages yet',
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade600,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTrailing() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          lastMessageTime,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 4),
        if (conversation.unreadCount > 0)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: ColorPalette.primaryGreen,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(
              minWidth: 20,
              minHeight: 20,
            ),
            child: Center(
              child: Text(
                conversation.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}