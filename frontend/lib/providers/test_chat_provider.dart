import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import 'auth_provider.dart';

class TestChatProvider extends ChangeNotifier {
  AuthProvider authProvider;
  final ChatService _chatService = ChatService();

  List<Conversation> _conversations = [];
  final Map<String, List<Message>> _messages = {};
  final Map<String, bool> _typingUsers = {};
  List<ChatRecipient> _recipients = [];
  int _totalUnread = 0;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _selectedConversationId;
  String? _error;

  TestChatProvider({required this.authProvider}) {
    _initialize();
  }

  List<Conversation> get conversations => _conversations;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  int get totalUnread => _totalUnread;
  String? get selectedConversationId => _selectedConversationId;
  Map<String, bool> get typingUsers => _typingUsers;
  List<ChatRecipient> get recipients => _recipients;
  String? get error => _error;

  List<Message> getMessages(String conversationId) {
    return _messages[conversationId] ?? const [];
  }

  int getUnreadCount(String conversationId) {
    try {
      return _conversations
          .firstWhere((conversation) => conversation.id == conversationId)
          .unreadCount;
    } catch (_) {
      return 0;
    }
  }

  bool isTyping(String userId) => _typingUsers[userId] ?? false;

  String get currentUserId => authProvider.user?.id ?? '';

  void updateAuthProvider(AuthProvider newAuthProvider) {
    if (identical(authProvider, newAuthProvider)) {
      return;
    }

    authProvider.removeListener(_onRoleChanged);
    authProvider = newAuthProvider;
    authProvider.addListener(_onRoleChanged);

    _messages.clear();
    _conversations = [];
    _recipients = [];
    _selectedConversationId = null;
    _isInitialized = false;
    _totalUnread = 0;

    if (authProvider.isAuthenticated) {
      loadConversations();
      loadRecipients();
    } else {
      notifyListeners();
    }
  }

  void _initialize() {
    authProvider.addListener(_onRoleChanged);
    if (authProvider.isAuthenticated) {
      loadConversations();
      loadRecipients();
    } else {
      _isInitialized = true;
    }
  }

  void _onRoleChanged() {
    if (!authProvider.isAuthenticated) {
      _conversations = [];
      _messages.clear();
      _recipients = [];
      _selectedConversationId = null;
      _totalUnread = 0;
      _isInitialized = true;
      notifyListeners();
      return;
    }

    loadConversations();
    loadRecipients();
  }

  Future<void> loadConversations() async {
    if (!authProvider.isAuthenticated) {
      _conversations = [];
      _messages.clear();
      _totalUnread = 0;
      _isInitialized = true;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _conversations = await _chatService.getConversations();
      _updateUnreadCounts();
      _isInitialized = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRecipients() async {
    if (!authProvider.isAuthenticated) {
      _recipients = [];
      notifyListeners();
      return;
    }

    _recipients = await _chatService.getRecipients();
    notifyListeners();
  }

  Future<void> loadMessages(String conversationId) async {
    if (!authProvider.isAuthenticated) {
      return;
    }

    _messages[conversationId] = await _chatService.getMessages(conversationId);
    notifyListeners();
  }

  Future<void> loadUnreadCounts() async {
    await loadConversations();
  }

  void selectConversation(String conversationId) {
    _selectedConversationId = conversationId.isEmpty ? null : conversationId;
    notifyListeners();
  }

  Future<void> markConversationAsRead(String conversationId) async {
    if (!authProvider.isAuthenticated) {
      return;
    }

    final success = await _chatService.markConversationAsRead(conversationId);
    if (!success) {
      return;
    }

    _messages[conversationId] = _messages[conversationId]
            ?.map(
              (message) => message.senderId == currentUserId
                  ? message
                  : Message(
                      id: message.id,
                      conversationId: message.conversationId,
                      senderId: message.senderId,
                      senderName: message.senderName,
                      senderImage: message.senderImage,
                      senderRole: message.senderRole,
                      content: message.content,
                      contentType: message.contentType,
                      attachments: message.attachments,
                      status: 'read',
                      readBy: message.readBy,
                      deliveredTo: message.deliveredTo,
                      isEdited: message.isEdited,
                      replyTo: message.replyTo,
                      isDeleted: message.isDeleted,
                      createdAt: message.createdAt,
                      timeAgo: message.timeAgo,
                    ),
            )
            .toList() ??
        const [];

    _conversations = _conversations
        .map((conversation) => conversation.id == conversationId
            ? Conversation(
                id: conversation.id,
                participants: conversation.participants,
                listingId: conversation.listingId,
                listingTitle: conversation.listingTitle,
                bookingId: conversation.bookingId,
                lastMessage: conversation.lastMessage,
                unreadCount: 0,
                isActive: conversation.isActive,
                createdAt: conversation.createdAt,
                updatedAt: conversation.updatedAt,
              )
            : conversation)
        .toList();

    _updateUnreadCounts();
    notifyListeners();
  }

  Future<String?> createConversation({
    required String participantId,
    String? listingId,
    String? bookingId,
    String? initialMessage,
  }) async {
    final conversation = await _chatService.createConversation(
      participantId: participantId,
      listingId: listingId,
      bookingId: bookingId,
      initialMessage: initialMessage,
    );

    if (conversation == null) {
      _error = _chatService.lastError ?? 'Failed to create conversation';
      notifyListeners();
      return null;
    }

    _upsertConversation(conversation);
    await loadMessages(conversation.id);
    return conversation.id;
  }

  Future<bool> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    final newMessage = await _chatService.sendMessage(
      conversationId: conversationId,
      content: content,
    );

    if (newMessage == null) {
      _error = _chatService.lastError ?? 'Failed to send message';
      notifyListeners();
      return false;
    }

    final existing = List<Message>.from(_messages[conversationId] ?? const []);
    existing.add(newMessage);
    _messages[conversationId] = existing;

    await loadConversations();
    return true;
  }

  void sendTyping(String conversationId, bool isTyping) {
    final conversation = _conversations.cast<Conversation?>().firstWhere(
          (item) => item?.id == conversationId,
          orElse: () => null,
        );
    if (conversation == null) {
      return;
    }

    final otherParticipant = conversation.participants.firstWhere(
      (participant) => participant.userId != currentUserId,
      orElse: () => Participant(
        userId: '',
        fullName: '',
        role: 'tourist',
        joinedAt: DateTime.now(),
        lastRead: DateTime.now(),
      ),
    );

    if (otherParticipant.userId.isEmpty) {
      return;
    }

    if (_typingUsers[otherParticipant.userId] == isTyping) {
      return;
    }

    _typingUsers[otherParticipant.userId] = isTyping;
    notifyListeners();
  }

  Future<bool> deleteConversation(String conversationId) async {
    final success = await _chatService.deleteConversation(conversationId);
    if (!success) {
      _error = 'Failed to delete conversation';
      notifyListeners();
      return false;
    }

    _conversations.removeWhere((conversation) => conversation.id == conversationId);
    _messages.remove(conversationId);
    _updateUnreadCounts();
    notifyListeners();
    return true;
  }

  Future<bool> deleteMessage(String messageId, String conversationId) async {
    final messages = _messages[conversationId];
    if (messages == null) {
      return true;
    }

    messages.removeWhere((message) => message.id == messageId);
    _messages[conversationId] = messages;
    notifyListeners();
    return true;
  }

  void _updateUnreadCounts() {
    _totalUnread = _conversations.fold<int>(
      0,
      (sum, conversation) => sum + conversation.unreadCount,
    );
  }

  void _upsertConversation(Conversation conversation) {
    _conversations.removeWhere((item) => item.id == conversation.id);
    _conversations.insert(0, conversation);
    _updateUnreadCounts();
    notifyListeners();
  }

  @override
  void dispose() {
    authProvider.removeListener(_onRoleChanged);
    super.dispose();
  }
}
