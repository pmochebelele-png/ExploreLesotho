// lib/data/models/conversation.dart
class Conversation {
  final String id;
  final List<Participant> participants;
  final String? listingId;
  final String? listingTitle;
  final String? bookingId;
  final LastMessage? lastMessage;
  final int unreadCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.participants,
    this.listingId,
    this.listingTitle,
    this.bookingId,
    this.lastMessage,
    this.unreadCount = 0,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final listingData =
        json['listingId'] is Map<String, dynamic> ? json['listingId'] as Map<String, dynamic> : null;
    final bookingData =
        json['bookingId'] is Map<String, dynamic> ? json['bookingId'] as Map<String, dynamic> : null;

    return Conversation(
      id: json['_id']?.toString() ?? '',
      participants: (json['participants'] as List? ?? [])
          .whereType<Map>()
          .map((p) => Participant.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      listingId: listingData?['_id']?.toString() ?? json['listingId']?.toString(),
      listingTitle: json['listingTitle']?.toString() ??
          listingData?['title']?.toString(),
      bookingId: bookingData?['_id']?.toString() ?? json['bookingId']?.toString(),
      lastMessage: json['lastMessage'] != null
          ? LastMessage.fromJson(
              Map<String, dynamic>.from(json['lastMessage'] as Map),
            )
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class Participant {
  final String userId;
  final String fullName;
  final String? profileImage;
  final String role;
  final DateTime joinedAt;
  final DateTime lastRead;

  Participant({
    required this.userId,
    required this.fullName,
    this.profileImage,
    required this.role,
    required this.joinedAt,
    required this.lastRead,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    final userData =
        json['userId'] is Map<String, dynamic> ? json['userId'] as Map<String, dynamic> : null;
    
    return Participant(
      userId: userData?['_id']?.toString() ?? json['userId']?.toString() ?? '',
      fullName: userData?['fullName']?.toString() ??
          json['fullName']?.toString() ??
          'Unknown User',
      profileImage: userData?['profileImage']?.toString(),
      role: json['role']?.toString() ?? 'tourist',
      joinedAt: DateTime.parse(json['joinedAt'] ?? DateTime.now().toIso8601String()),
      lastRead: DateTime.parse(json['lastRead'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class LastMessage {
  final String content;
  final String senderId;
  final DateTime sentAt;

  LastMessage({
    required this.content,
    required this.senderId,
    required this.sentAt,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    return LastMessage(
      content: json['content'] ?? '',
      senderId: json['senderId']?.toString() ?? '',
      sentAt: DateTime.parse(json['sentAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
