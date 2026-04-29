// lib/providers/wishlist_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/listing.dart';
import '../services/api_service.dart';

class WishlistProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Listing> _wishlistItems = [];
  bool _isLoading = false;
  String? _shareId;

  List<Listing> get wishlistItems => _wishlistItems;
  bool get isLoading => _isLoading;
  int get wishlistCount => _wishlistItems.length;

  WishlistProvider() {
    loadWishlistFromLocal();
    _loadShareId();
  }

  // Load wishlist from local storage
  Future<void> loadWishlistFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wishlistJson = prefs.getString('wishlist');
      if (wishlistJson != null) {
        final List<dynamic> decoded = json.decode(wishlistJson);
        _wishlistItems = decoded.map((item) => Listing.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error loading wishlist: $e');
    }
  }

  // Load share ID
  Future<void> _loadShareId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _shareId = prefs.getString('wishlist_share_id');
    } catch (e) {
      print('❌ Error loading share ID: $e');
    }
  }

  // Generate share ID for wishlist
  Future<String> generateShareId() async {
    if (_shareId != null) return _shareId!;
    
    final prefs = await SharedPreferences.getInstance();
    _shareId = DateTime.now().millisecondsSinceEpoch.toString();
    await prefs.setString('wishlist_share_id', _shareId!);
    return _shareId!;
  }

  // Generate shareable wishlist text
  Future<String> generateShareMessage(String userName) async {
    if (_wishlistItems.isEmpty) {
      return 'My wishlist is empty. Add some places to explore Lesotho!';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('🌟 $userName\'s Explore Lesotho Wishlist 🌟');
    buffer.writeln('📍 ${_wishlistItems.length} amazing places to visit\n');
    
    for (int i = 0; i < _wishlistItems.length && i < 10; i++) {
      final item = _wishlistItems[i];
      buffer.writeln('${i + 1}. ${item.title}');
      if (item.rating != null && item.rating! > 0) {
        buffer.writeln('   ⭐ ${item.rating!.toStringAsFixed(1)} ★');
      }
      if (item.location.isNotEmpty) {
        buffer.writeln('   📍 ${item.location}');
      }
      buffer.writeln();
    }
    
    if (_wishlistItems.length > 10) {
      buffer.writeln('... and ${_wishlistItems.length - 10} more places!');
    }
    
    buffer.writeln('\n✨ Plan your next adventure with Explore Lesotho!');
    buffer.writeln('📱 Download the app: https://explorelesotho.com/app');
    
    return buffer.toString();
  }

  // Get shareable data for backend
  Future<Map<String, dynamic>> getShareableData() async {
    final shareId = await generateShareId();
    return {
      'shareId': shareId,
      'items': _wishlistItems.map((item) => item.toJson()).toList(),
      'itemCount': _wishlistItems.length,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  // Save wishlist to local storage
  Future<void> _saveWishlistToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wishlistJson = json.encode(_wishlistItems.map((item) => item.toJson()).toList());
      await prefs.setString('wishlist', wishlistJson);
    } catch (e) {
      print('❌ Error saving wishlist: $e');
    }
  }

  // Add to wishlist
  Future<bool> addToWishlist(Listing listing) async {
    try {
      if (_wishlistItems.any((item) => item.id == listing.id)) {
        return false;
      }
      
      _wishlistItems.add(listing);
      await _saveWishlistToLocal();
      notifyListeners();
      await _syncWishlistToBackend();
      
      return true;
    } catch (e) {
      print('❌ Error adding to wishlist: $e');
      return false;
    }
  }

  // Remove from wishlist
  Future<bool> removeFromWishlist(String listingId) async {
    try {
      _wishlistItems.removeWhere((item) => item.id == listingId);
      await _saveWishlistToLocal();
      notifyListeners();
      await _syncWishlistToBackend();
      
      return true;
    } catch (e) {
      print('❌ Error removing from wishlist: $e');
      return false;
    }
  }

  // Check if listing is in wishlist
  bool isInWishlist(String listingId) {
    return _wishlistItems.any((item) => item.id == listingId);
  }

  // Sync wishlist with backend
  Future<void> _syncWishlistToBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token != null) {
        final wishlistIds = _wishlistItems.map((item) => item.id).toList();
        await _apiService.post('/wishlist/sync', {
          'wishlist_ids': wishlistIds,
          'share_id': _shareId,
        });
      }
    } catch (e) {
      print('⚠️ Could not sync wishlist to backend: $e');
    }
  }

  // Clear wishlist
  Future<void> clearWishlist() async {
    _wishlistItems.clear();
    await _saveWishlistToLocal();
    notifyListeners();
  }

  // Fetch wishlist from backend
  Future<void> fetchWishlistFromBackend() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token != null) {
        final response = await _apiService.get('/wishlist');
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            final listings = data['listings'] ?? [];
            _wishlistItems = listings.map((item) => Listing.fromJson(item)).toList();
            await _saveWishlistToLocal();
          }
        }
      }
    } catch (e) {
      print('❌ Error fetching wishlist from backend: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}