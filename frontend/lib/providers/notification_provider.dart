// lib/providers/notification_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/listing.dart';
import '../services/api_service.dart';
import '../services/local_notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<WishlistNotification> _notifications = [];
  final bool _isLoading = false;
  bool _notificationsEnabled = true;
  bool _priceDropEnabled = true;
  bool _availabilityEnabled = true;
  bool _newListingsEnabled = true;
  bool _dealsEnabled = true;

  List<WishlistNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get priceDropEnabled => _priceDropEnabled;
  bool get availabilityEnabled => _availabilityEnabled;
  bool get newListingsEnabled => _newListingsEnabled;
  bool get dealsEnabled => _dealsEnabled;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider() {
    _loadSettings();
    _loadNotifications();
    _startListeningForUpdates();
  }

  // Load notification settings
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool('wishlist_notifications_enabled') ?? true;
      _priceDropEnabled = prefs.getBool('price_drop_notifications') ?? true;
      _availabilityEnabled = prefs.getBool('availability_notifications') ?? true;
      _newListingsEnabled = prefs.getBool('new_listings_notifications') ?? true;
      _dealsEnabled = prefs.getBool('deals_notifications') ?? true;
      notifyListeners();
    } catch (e) {
      print('❌ Error loading settings: $e');
    }
  }

  // Load notifications
  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString('wishlist_notifications');
      if (notificationsJson != null) {
        final List<dynamic> decoded = json.decode(notificationsJson);
        _notifications = decoded.map((n) => WishlistNotification.fromJson(n)).toList();
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error loading notifications: $e');
    }
  }

  // Save notifications
  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = json.encode(_notifications.map((n) => n.toJson()).toList());
      await prefs.setString('wishlist_notifications', notificationsJson);
    } catch (e) {
      print('❌ Error saving notifications: $e');
    }
  }

  Future<void> refresh() async {
    await _loadNotifications();
  }

  // Save settings
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('wishlist_notifications_enabled', _notificationsEnabled);
      await prefs.setBool('price_drop_notifications', _priceDropEnabled);
      await prefs.setBool('availability_notifications', _availabilityEnabled);
      await prefs.setBool('new_listings_notifications', _newListingsEnabled);
      await prefs.setBool('deals_notifications', _dealsEnabled);
    } catch (e) {
      print('❌ Error saving settings: $e');
    }
  }

  // Add notification
  Future<void> addNotification({
    required String title,
    required String message,
    required NotificationType type,
    required String listingId,
    String? listingTitle,
    double? oldPrice,
    double? newPrice,
  }) async {
    if (!_notificationsEnabled) return;
    
    // Check if user has enabled this notification type
    switch (type) {
      case NotificationType.priceDrop:
        if (!_priceDropEnabled) return;
        break;
      case NotificationType.availability:
        if (!_availabilityEnabled) return;
        break;
      case NotificationType.newListing:
        if (!_newListingsEnabled) return;
        break;
      case NotificationType.deal:
        if (!_dealsEnabled) return;
        break;
    }

    final notification = WishlistNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      listingId: listingId,
      listingTitle: listingTitle,
      oldPrice: oldPrice,
      newPrice: newPrice,
      createdAt: DateTime.now(),
      isRead: false,
    );

    _notifications.insert(0, notification);
    await _saveNotifications();
    notifyListeners();

    // Show local notification
    await LocalNotificationService.showWishlistNotification(
      title: title,
      body: message,
      payload: listingId,
    );
  }

  // Mark as read
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _saveNotifications();
      notifyListeners();
    }
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    await _saveNotifications();
    notifyListeners();
  }

  // Clear all notifications
  Future<void> clearAll() async {
    _notifications.clear();
    await _saveNotifications();
    notifyListeners();
  }

  // Remove notification
  Future<void> removeNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    await _saveNotifications();
    notifyListeners();
  }

  // Update settings
  Future<void> updateSettings({
    bool? notificationsEnabled,
    bool? priceDropEnabled,
    bool? availabilityEnabled,
    bool? newListingsEnabled,
    bool? dealsEnabled,
  }) async {
    if (notificationsEnabled != null) _notificationsEnabled = notificationsEnabled;
    if (priceDropEnabled != null) _priceDropEnabled = priceDropEnabled;
    if (availabilityEnabled != null) _availabilityEnabled = availabilityEnabled;
    if (newListingsEnabled != null) _newListingsEnabled = newListingsEnabled;
    if (dealsEnabled != null) _dealsEnabled = dealsEnabled;
    
    await _saveSettings();
    notifyListeners();
  }

  // Listen for price changes (simulated)
  void _startListeningForUpdates() {
    // In a real app, this would use WebSockets or periodic API calls
    // For demo, we'll simulate checking every 30 seconds
    Future.delayed(const Duration(seconds: 30), _checkForUpdates);
  }

  Future<void> _checkForUpdates() async {
    // This would check for price drops, availability changes, etc.
    // For demo, we'll simulate
    print('🔍 Checking for wishlist updates...');
    
    // Simulate periodic check
    Future.delayed(const Duration(seconds: 60), _checkForUpdates);
  }

  // Simulate price drop notification (for testing)
  Future<void> simulatePriceDrop(Listing listing, double newPrice) async {
    await addNotification(
      title: 'Price Drop! 🎉',
      message: '${listing.title} is now M$newPrice (was M${listing.price})',
      type: NotificationType.priceDrop,
      listingId: listing.id,
      listingTitle: listing.title,
      oldPrice: listing.price,
      newPrice: newPrice,
    );
  }

  // Simulate availability notification
  Future<void> simulateAvailability(Listing listing) async {
    await addNotification(
      title: 'Now Available! ✅',
      message: '${listing.title} is now available for booking',
      type: NotificationType.availability,
      listingId: listing.id,
      listingTitle: listing.title,
    );
  }

  // Simulate deal notification
  Future<void> simulateDeal(Listing listing) async {
    await addNotification(
      title: 'Special Deal! 🔥',
      message: 'Book ${listing.title} this week and get 15% off!',
      type: NotificationType.deal,
      listingId: listing.id,
      listingTitle: listing.title,
    );
  }
}

// Notification Model
class WishlistNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final String listingId;
  final String? listingTitle;
  final double? oldPrice;
  final double? newPrice;
  final DateTime createdAt;
  final bool isRead;

  WishlistNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.listingId,
    this.listingTitle,
    this.oldPrice,
    this.newPrice,
    required this.createdAt,
    required this.isRead,
  });

  factory WishlistNotification.fromJson(Map<String, dynamic> json) {
    return WishlistNotification(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => NotificationType.priceDrop,
      ),
      listingId: json['listingId'],
      listingTitle: json['listingTitle'],
      oldPrice: json['oldPrice']?.toDouble(),
      newPrice: json['newPrice']?.toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['isRead'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.toString(),
      'listingId': listingId,
      'listingTitle': listingTitle,
      'oldPrice': oldPrice,
      'newPrice': newPrice,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  WishlistNotification copyWith({bool? isRead}) {
    return WishlistNotification(
      id: id,
      title: title,
      message: message,
      type: type,
      listingId: listingId,
      listingTitle: listingTitle,
      oldPrice: oldPrice,
      newPrice: newPrice,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

enum NotificationType {
  priceDrop,
  availability,
  newListing,
  deal,
}