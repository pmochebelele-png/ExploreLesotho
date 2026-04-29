import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/conversation.dart';
import '../models/message.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

class ChatRecipient {
  final String id;
  final String name;
  final String role;
  final String? email;

  ChatRecipient({
    required this.id,
    required this.name,
    required this.role,
    this.email,
  });

  factory ChatRecipient.fromJson(Map<String, dynamic> json) {
    return ChatRecipient(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown User',
      role: json['role']?.toString() ?? 'tourist',
      email: json['email']?.toString(),
    );
  }
}

class ChatService {
  final String baseUrl = Constants.baseUrl;
  final AuthService _authService = AuthService();
  String? _lastError;

  String? get lastError => _lastError;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Conversation>> getConversations() async {
    try {
      _lastError = null;
      final response = await http.get(
        Uri.parse('$baseUrl/chat/conversations'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        _lastError = 'Failed to load conversations';
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final conversations = <Conversation>[];
      for (final item in (data['conversations'] as List? ?? const [])) {
        try {
          conversations.add(
            Conversation.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          );
        } catch (e) {
          _lastError = 'Bad conversation row: $e';
        }
      }
      return conversations;
    } catch (e) {
      _lastError = e.toString();
      return [];
    }
  }

  Future<List<Message>> getMessages(String conversationId) async {
    try {
      _lastError = null;
      final response = await http.get(
        Uri.parse('$baseUrl/chat/conversations/$conversationId/messages'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        _lastError = 'Failed to load messages';
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final messages = <Message>[];
      for (final item in (data['messages'] as List? ?? const [])) {
        try {
          messages.add(
            Message.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          );
        } catch (e) {
          _lastError = 'Bad message row: $e';
        }
      }
      return messages;
    } catch (e) {
      _lastError = e.toString();
      return [];
    }
  }

  Future<List<ChatRecipient>> getRecipients() async {
    try {
      _lastError = null;
      final response = await http.get(
        Uri.parse('$baseUrl/chat/recipients'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        _lastError = 'Failed to load recipients';
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final recipients = <ChatRecipient>[];
      for (final item in (data['recipients'] as List? ?? const [])) {
        try {
          recipients.add(
            ChatRecipient.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          );
        } catch (e) {
          _lastError = 'Bad recipient row: $e';
        }
      }
      return recipients;
    } catch (e) {
      _lastError = e.toString();
      return [];
    }
  }

  Future<Conversation?> createConversation({
    required String participantId,
    String? listingId,
    String? bookingId,
    String? initialMessage,
  }) async {
    try {
      _lastError = null;
      final response = await http.post(
        Uri.parse('$baseUrl/chat/conversations'),
        headers: await _getHeaders(),
        body: json.encode({
          'participantId': participantId,
          'listingId': listingId,
          'bookingId': bookingId,
          'initialMessage': initialMessage,
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          _lastError = data['error']?.toString() ??
              data['message']?.toString() ??
              'Failed to create conversation';
        } catch (_) {
          _lastError = 'Failed to create conversation';
        }
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final conversation = data['conversation'];
      if (conversation is! Map<String, dynamic>) {
        return null;
      }
      return Conversation.fromJson(conversation);
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  Future<Message?> sendMessage({
    required String conversationId,
    required String content,
    String contentType = 'text',
  }) async {
    try {
      _lastError = null;
      final response = await http.post(
        Uri.parse('$baseUrl/chat/conversations/$conversationId/messages'),
        headers: await _getHeaders(),
        body: json.encode({
          'content': content,
          'contentType': contentType,
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          _lastError = data['error']?.toString() ??
              data['message']?.toString() ??
              'Failed to send message';
        } catch (_) {
          _lastError = 'Failed to send message';
        }
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final message = data['message'];
      if (message is! Map<String, dynamic>) {
        return null;
      }
      return Message.fromJson(message);
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  Future<bool> markConversationAsRead(String conversationId) async {
    try {
      _lastError = null;
      final response = await http.post(
        Uri.parse('$baseUrl/chat/conversations/$conversationId/read'),
        headers: await _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  Future<bool> deleteConversation(String conversationId) async {
    try {
      _lastError = null;
      final response = await http.delete(
        Uri.parse('$baseUrl/chat/conversations/$conversationId'),
        headers: await _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }
}
