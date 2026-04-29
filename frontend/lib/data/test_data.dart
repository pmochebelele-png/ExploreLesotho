// lib/data/test_data.dart
import '../models/conversation.dart';
import '../models/message.dart';

class TestListing {
  final String id;
  final String title;
  final String description;
  final String category;
  final double price;
  final String location;
  final String district;
  final double rating;
  final int reviewCount;
  final bool isAvailable;
  final String imageUrl;
  final String vendorId;      // ✅ ADDED
  final String vendorName;    // ✅ ADDED

  TestListing({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.location,
    required this.district,
    required this.rating,
    required this.reviewCount,
    required this.isAvailable,
    required this.imageUrl,
    required this.vendorId,
    required this.vendorName,
  });
}

class TestData {
  // ==================== LISTINGS DATA ====================
  static List<TestListing> getListings() {
    return [
      TestListing(
        id: 'listing1',
        title: 'Maliba Mountain Lodge',
        description: 'Luxury mountain lodge in the Maluti Mountains',
        category: 'Accommodation',
        price: 1850,
        location: 'Tsehlanyane National Park',
        district: 'Butha-Buthe',
        rating: 4.8,
        reviewCount: 24,
        isAvailable: true,
        imageUrl: '',
        vendorId: 'vendor1',
        vendorName: 'Mountain Adventures',
      ),
      TestListing(
        id: 'listing2',
        title: 'Pony Trekking Adventure',
        description: 'Experience Lesotho on horseback',
        category: 'Experience',
        price: 650,
        location: 'Malealea',
        district: 'Mafeteng',
        rating: 4.9,
        reviewCount: 56,
        isAvailable: true,
        imageUrl: '',
        vendorId: 'vendor1',
        vendorName: 'Mountain Adventures',
      ),
      TestListing(
        id: 'listing3',
        title: 'Sani Pass 4x4 Tour',
        description: 'Thrilling drive up the highest mountain pass',
        category: 'Adventure',
        price: 1200,
        location: 'Sani Pass',
        district: 'Mokhotlong',
        rating: 5.0,
        reviewCount: 78,
        isAvailable: true,
        imageUrl: '',
        vendorId: 'vendor1',
        vendorName: 'Mountain Adventures',
      ),
      TestListing(
        id: 'listing4',
        title: 'Basotho Cultural Village',
        description: 'Immerse yourself in Basotho culture',
        category: 'Culture',
        price: 350,
        location: 'QwaQwa',
        district: 'Thaba Tseka',
        rating: 4.7,
        reviewCount: 32,
        isAvailable: true,
        imageUrl: '',
        vendorId: 'vendor2',
        vendorName: 'Cultural Tours Lesotho',
      ),
      TestListing(
        id: 'listing5',
        title: 'Katse Dam Lodge',
        description: 'Beautiful lodge overlooking Katse Dam',
        category: 'Accommodation',
        price: 2100,
        location: 'Katse',
        district: 'Leribe',
        rating: 4.6,
        reviewCount: 45,
        isAvailable: true,
        imageUrl: '',
        vendorId: 'vendor2',
        vendorName: 'Cultural Tours Lesotho',
      ),
    ];
  }

  // ==================== CONVERSATIONS DATA ====================
  static List<Conversation> getConversations(String currentUserId) {
    return [
      Conversation(
        id: 'conv1',
        participants: [
          Participant(
            userId: 'admin1',
            fullName: 'Admin User',
            role: 'admin',
            joinedAt: DateTime.now().subtract(const Duration(days: 2)),
            lastRead: DateTime.now(),
          ),
          Participant(
            userId: 'vendor1',
            fullName: 'Vendor One',
            role: 'vendor',
            joinedAt: DateTime.now().subtract(const Duration(days: 2)),
            lastRead: DateTime.now(),
          ),
        ],
        lastMessage: LastMessage(
          content: 'When can you provide the listings?',
          senderId: 'admin1',
          sentAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
        unreadCount: currentUserId == 'admin1' ? 0 : 2,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      Conversation(
        id: 'conv2',
        participants: [
          Participant(
            userId: 'vendor1',
            fullName: 'Vendor One',
            role: 'vendor',
            joinedAt: DateTime.now().subtract(const Duration(days: 1)),
            lastRead: DateTime.now(),
          ),
          Participant(
            userId: 'tourist1',
            fullName: 'Tourist One',
            role: 'tourist',
            joinedAt: DateTime.now().subtract(const Duration(days: 1)),
            lastRead: DateTime.now(),
          ),
        ],
        lastMessage: LastMessage(
          content: 'Is the Maletsunyane tour available next week?',
          senderId: 'tourist1',
          sentAt: DateTime.now().subtract(const Duration(minutes: 15)),
        ),
        unreadCount: currentUserId == 'tourist1' ? 0 : 1,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      Conversation(
        id: 'conv3',
        participants: [
          Participant(
            userId: 'admin1',
            fullName: 'Admin User',
            role: 'admin',
            joinedAt: DateTime.now().subtract(const Duration(hours: 5)),
            lastRead: DateTime.now(),
          ),
          Participant(
            userId: 'tourist1',
            fullName: 'Tourist One',
            role: 'tourist',
            joinedAt: DateTime.now().subtract(const Duration(hours: 5)),
            lastRead: DateTime.now(),
          ),
        ],
        lastMessage: LastMessage(
          content: 'Thank you for your help with the booking!',
          senderId: 'tourist1',
          sentAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        unreadCount: currentUserId == 'admin1' ? 1 : 0,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ];
  }

  // ==================== MESSAGES DATA ====================
  static List<Message> getMessages(String conversationId, String currentUserId) {
    final now = DateTime.now();
    
    if (conversationId == 'conv1') {
      return [
        Message(
          id: 'msg1',
          conversationId: 'conv1',
          senderId: 'admin1',
          senderName: 'Admin User',
          senderRole: 'admin',
          content: 'Hello, I need to discuss the new listings',
          status: 'read',
          createdAt: now.subtract(const Duration(hours: 2)),
          timeAgo: '2h ago',
        ),
        Message(
          id: 'msg2',
          conversationId: 'conv1',
          senderId: 'vendor1',
          senderName: 'Vendor One',
          senderRole: 'vendor',
          content: 'Sure, what would you like to know?',
          status: 'read',
          createdAt: now.subtract(const Duration(hours: 1)),
          timeAgo: '1h ago',
        ),
        Message(
          id: 'msg3',
          conversationId: 'conv1',
          senderId: 'admin1',
          senderName: 'Admin User',
          senderRole: 'admin',
          content: 'When can you provide the listings?',
          status: currentUserId == 'vendor1' ? 'delivered' : 'read',
          createdAt: now.subtract(const Duration(minutes: 30)),
          timeAgo: '30m ago',
        ),
        Message(
          id: 'msg10',
          conversationId: 'conv1',
          senderId: 'vendor1',
          senderName: 'Vendor One',
          senderRole: 'vendor',
          content: '🎤 Voice message|/storage/emulated/0/voice_123456789.m4a',
          status: 'read',
          createdAt: now.subtract(const Duration(minutes: 10)),
          timeAgo: '10m ago',
        ),
      ];
    } else if (conversationId == 'conv2') {
      return [
        Message(
          id: 'msg4',
          conversationId: 'conv2',
          senderId: 'tourist1',
          senderName: 'Tourist One',
          senderRole: 'tourist',
          content: "Hi, I'm interested in the pony trekking",
          status: 'read',
          createdAt: now.subtract(const Duration(hours: 3)),
          timeAgo: '3h ago',
        ),
        Message(
          id: 'msg5',
          conversationId: 'conv2',
          senderId: 'vendor1',
          senderName: 'Vendor One',
          senderRole: 'vendor',
          content: 'Great! We have slots available this weekend',
          status: 'read',
          createdAt: now.subtract(const Duration(hours: 2)),
          timeAgo: '2h ago',
        ),
        Message(
          id: 'msg6',
          conversationId: 'conv2',
          senderId: 'tourist1',
          senderName: 'Tourist One',
          senderRole: 'tourist',
          content: 'Is the Maletsunyane tour available next week?',
          status: currentUserId == 'vendor1' ? 'delivered' : 'read',
          createdAt: now.subtract(const Duration(minutes: 15)),
          timeAgo: '15m ago',
        ),
      ];
    } else {
      return [
        Message(
          id: 'msg7',
          conversationId: 'conv3',
          senderId: 'tourist1',
          senderName: 'Tourist One',
          senderRole: 'tourist',
          content: 'Can you help me with my booking?',
          status: 'read',
          createdAt: now.subtract(const Duration(hours: 1)),
          timeAgo: '1h ago',
        ),
        Message(
          id: 'msg8',
          conversationId: 'conv3',
          senderId: 'admin1',
          senderName: 'Admin User',
          senderRole: 'admin',
          content: 'Of course, what seems to be the issue?',
          status: 'read',
          createdAt: now.subtract(const Duration(minutes: 45)),
          timeAgo: '45m ago',
        ),
        Message(
          id: 'msg9',
          conversationId: 'conv3',
          senderId: 'tourist1',
          senderName: 'Tourist One',
          senderRole: 'tourist',
          content: 'Thank you for your help with the booking!',
          status: currentUserId == 'admin1' ? 'delivered' : 'read',
          createdAt: now.subtract(const Duration(minutes: 5)),
          timeAgo: '5m ago',
        ),
      ];
    }
  }
}