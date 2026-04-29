
// lib/models/message.dart
class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderImage;
  final String senderRole;
  final String content;
  final String contentType;
  final List<Attachment> attachments;
  final String status;
  final List<ReadReceipt> readBy;
  final List<DeliveredReceipt> deliveredTo;
  final bool isEdited;
  final ReplyTo? replyTo;
  final bool isDeleted;
  final DateTime createdAt;
  final String timeAgo;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderImage,
    required this.senderRole,
    required this.content,
    this.contentType = 'text',
    this.attachments = const [],
    this.status = 'sent',
    this.readBy = const [],
    this.deliveredTo = const [],
    this.isEdited = false,
    this.replyTo,
    this.isDeleted = false,
    required this.createdAt,
    required this.timeAgo,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final senderData = json['senderId'] is Map ? json['senderId'] : null;
    
    return Message(
      id: json['_id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: senderData?['_id']?.toString() ?? json['senderId']?.toString() ?? '',
      senderName: senderData?['fullName']?.toString() ?? 'Unknown User',
      senderImage: senderData?['profileImage']?.toString(),
      senderRole: json['senderRole'] ?? 'tourist',
      content: json['content'] ?? '',
      contentType: json['contentType'] ?? 'text',
      attachments: (json['attachments'] as List? ?? [])
          .map((a) => Attachment.fromJson(a))
          .toList(),
      status: json['status'] ?? 'sent',
      readBy: (json['readBy'] as List? ?? [])
          .map((r) => ReadReceipt.fromJson(r))
          .toList(),
      deliveredTo: (json['deliveredTo'] as List? ?? [])
          .map((d) => DeliveredReceipt.fromJson(d))
          .toList(),
      isEdited: json['isEdited'] ?? false,
      replyTo: json['replyTo'] != null
          ? ReplyTo.fromJson(json['replyTo'])
          : null,
      isDeleted: json['isDeleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      timeAgo: json['timeAgo'] ?? 'just now',
    );
  }

  bool get isSentByMe => false; // Will be set by provider
  bool get isRead => readBy.isNotEmpty;
  bool get isDelivered => deliveredTo.isNotEmpty;

  Map<String, dynamic> toJson() => {
        '_id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'senderName': senderName,
        'senderImage': senderImage,
        'senderRole': senderRole,
        'content': content,
        'contentType': contentType,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'status': status,
        'readBy': readBy.map((r) => r.toJson()).toList(),
        'deliveredTo': deliveredTo.map((d) => d.toJson()).toList(),
        'isEdited': isEdited,
        'replyTo': replyTo?.toJson(),
        'isDeleted': isDeleted,
        'createdAt': createdAt.toIso8601String(),
        'timeAgo': timeAgo,
      };
}

class Attachment {
  final String url;
  final String type;
  final String name;
  final int size;

  Attachment({
    required this.url,
    required this.type,
    required this.name,
    required this.size,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      url: json['url'] ?? '',
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      size: json['size'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'type': type,
        'name': name,
        'size': size,
      };
}

class ReadReceipt {
  final String userId;
  final DateTime readAt;

  ReadReceipt({
    required this.userId,
    required this.readAt,
  });

  factory ReadReceipt.fromJson(Map<String, dynamic> json) {
    return ReadReceipt(
      userId: json['userId']?.toString() ?? '',
      readAt: DateTime.parse(json['readAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'readAt': readAt.toIso8601String(),
      };
}

class DeliveredReceipt {
  final String userId;
  final DateTime deliveredAt;

  DeliveredReceipt({
    required this.userId,
    required this.deliveredAt,
  });

  factory DeliveredReceipt.fromJson(Map<String, dynamic> json) {
    return DeliveredReceipt(
      userId: json['userId']?.toString() ?? '',
      deliveredAt: DateTime.parse(json['deliveredAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'deliveredAt': deliveredAt.toIso8601String(),
      };
}

class ReplyTo {
  final String messageId;
  final String content;
  final String senderName;

  ReplyTo({
    required this.messageId,
    required this.content,
    required this.senderName,
  });

  factory ReplyTo.fromJson(Map<String, dynamic> json) {
    return ReplyTo(
      messageId: json['messageId']?.toString() ?? '',
      content: json['content'] ?? '',
      senderName: json['senderName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'content': content,
        'senderName': senderName,
      };
}