// lib/screens/chat/new_message_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/test_chat_provider.dart';
import '../../providers/listing_provider.dart';
import '../../core/themes/color_palette.dart';

class NewMessageScreen extends StatefulWidget {
  final Set<String>? allowedRoles;
  final String? initialRecipientId;
  final String? initialRecipientName;
  final String? initialListingId;
  final String title;
  final bool lockRecipient;

  const NewMessageScreen({
    super.key,
    this.allowedRoles,
    this.initialRecipientId,
    this.initialRecipientName,
    this.initialListingId,
    this.title = 'New Message',
    this.lockRecipient = false,
  });

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  String? _selectedUserId;
  String? _selectedListingId;
  List<Map<String, dynamic>> _availableUsers = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.initialRecipientId;
    _selectedListingId = widget.initialListingId;
    _loadAvailableUsers();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableUsers() async {
    final chatProvider = Provider.of<TestChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await chatProvider.loadRecipients();
    final allowedRoles = widget.allowedRoles ?? _defaultAllowedRoles(authProvider);
    _availableUsers = chatProvider.recipients
        .where((recipient) => allowedRoles.contains(recipient.role))
        .map((recipient) => {
              'id': recipient.id,
              'name': recipient.name,
              'role': recipient.role,
              'avatar': recipient.name.isNotEmpty ? recipient.name[0].toUpperCase() : '?',
            })
        .toList();
    if (widget.initialRecipientId != null &&
        !_availableUsers.any((user) => user['id'] == widget.initialRecipientId)) {
      final fallbackName = widget.initialRecipientName ?? 'Selected recipient';
      _availableUsers.insert(0, {
        'id': widget.initialRecipientId!,
        'name': fallbackName,
        'role': allowedRoles.isNotEmpty ? allowedRoles.first : 'vendor',
        'avatar': fallbackName.isNotEmpty ? fallbackName[0].toUpperCase() : '?',
      });
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startConversation() async {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a recipient')),
      );
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    final chatProvider = Provider.of<TestChatProvider>(context, listen: false);
    setState(() => _isSending = true);

    final conversationId = await chatProvider.createConversation(
      participantId: _selectedUserId!,
      listingId: _selectedListingId,
      initialMessage: _messageController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (conversationId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message sent!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chatProvider.error ?? 'Failed to send message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingProvider = Provider.of<ListingProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: ColorPalette.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'To:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (widget.lockRecipient && _selectedUserId != null)
            _buildLockedRecipientCard()
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: _availableUsers.map((user) {
                  return RadioListTile<String>(
                    title: Text(user['name']),
                    subtitle: Text(_getRoleDisplay(user['role'])),
                    value: user['id'],
                    groupValue: _selectedUserId,
                    onChanged: (value) {
                      setState(() {
                        _selectedUserId = value;
                      });
                    },
                    secondary: CircleAvatar(
                      backgroundColor:
                          _getRoleColor(user['role']).withOpacity(0.2),
                      child: Text(
                        user['avatar'],
                        style: TextStyle(
                          color: _getRoleColor(user['role']),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 16),

          const Text(
            'Regarding a listing? (Optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (widget.initialListingId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                listingProvider.getListingById(widget.initialListingId!)?.title ??
                    'Selected listing',
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: listingProvider.listings.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No listings available'),
                    )
                  : DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      hint: const Text('Select a listing'),
                      initialValue: _selectedListingId,
                      items: listingProvider.listings.map((listing) {
                        return DropdownMenuItem(
                          value: listing.id,
                          child: Text(listing.title),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedListingId = value;
                        });
                      },
                    ),
            ),

          const SizedBox(height: 16),

          const Text(
            'Message:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Type your message here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isSending ? null : _startConversation,
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorPalette.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Send Message',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
          if (_availableUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'No recipients available yet',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getRoleDisplay(String role) {
    switch (role) {
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

  Color _getRoleColor(String role) {
    switch (role) {
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

  Set<String> _defaultAllowedRoles(AuthProvider authProvider) {
    if (authProvider.isTourist || authProvider.isAdmin) {
      return {'vendor'};
    }
    if (authProvider.isVendor) {
      return {'tourist', 'admin'};
    }
    return {'vendor'};
  }

  Widget _buildLockedRecipientCard() {
    final user = _availableUsers.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['id'] == _selectedUserId,
          orElse: () => null,
        ) ??
        {
          'name': widget.initialRecipientName ?? 'Selected recipient',
          'role': widget.allowedRoles?.isNotEmpty == true
              ? widget.allowedRoles!.first
              : 'vendor',
          'avatar': (widget.initialRecipientName?.isNotEmpty ?? false)
              ? widget.initialRecipientName![0].toUpperCase()
              : '?',
        };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _getRoleColor(user['role']).withOpacity(0.2),
            child: Text(
              user['avatar'],
              style: TextStyle(
                color: _getRoleColor(user['role']),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'],
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _getRoleDisplay(user['role']),
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
