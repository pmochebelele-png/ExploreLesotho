// lib/services/offline_storage_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../models/booking.dart';
import '../models/listing.dart';
import '../models/user.dart';

class OfflineStorageService {
  static OfflineStorageService? _instance;
  static OfflineStorageService get instance {
    _instance ??= OfflineStorageService._internal();
    return _instance!;
  }
  
  // Box names
  static const String bookingsBoxName = 'bookings';
  static const String listingsBoxName = 'listings';
  static const String userBoxName = 'user_data';
  static const String favoritesBoxName = 'favorites';
  
  late Box<String> _bookingsBox;
  late Box<String> _listingsBox;
  late Box<String> _userBox;
  late Box<String> _favoritesBox;
  
  bool _initialized = false;
  
  OfflineStorageService._internal();
  
  Future<void> init() async {
    if (_initialized) return;
    
    await Hive.initFlutter();
    
    _bookingsBox = await Hive.openBox<String>(bookingsBoxName);
    _listingsBox = await Hive.openBox<String>(listingsBoxName);
    _userBox = await Hive.openBox<String>(userBoxName);
    _favoritesBox = await Hive.openBox<String>(favoritesBoxName);
    
    _initialized = true;
  }
  
  // ============= BOOKINGS =============
  Future<void> saveBooking(Booking booking) async {
    await _bookingsBox.put(booking.id, jsonEncode(booking.toJson()));
  }
  
  List<Booking> getBookings() {
    final List<Booking> bookings = [];
    for (var key in _bookingsBox.keys) {
      final data = _bookingsBox.get(key);
      if (data != null) {
        try {
          bookings.add(Booking.fromJson(jsonDecode(data)));
        } catch (e) {
          print('Error decoding booking: $e');
        }
      }
    }
    return bookings;
  }
  
  Booking? getBooking(String id) {
    final data = _bookingsBox.get(id);
    if (data != null) {
      try {
        return Booking.fromJson(jsonDecode(data));
      } catch (e) {
        print('Error decoding booking: $e');
      }
    }
    return null;
  }
  
  Future<void> deleteBooking(String id) async {
    await _bookingsBox.delete(id);
  }
  
  // ============= LISTINGS =============
  Future<void> saveListings(List<Listing> listings) async {
    await _listingsBox.clear();
    for (final listing in listings) {
      await _listingsBox.put(listing.id, jsonEncode(listing.toJson()));
    }
  }
  
  List<Listing> getListings() {
    final List<Listing> listings = [];
    for (var key in _listingsBox.keys) {
      final data = _listingsBox.get(key);
      if (data != null) {
        try {
          listings.add(Listing.fromJson(jsonDecode(data)));
        } catch (e) {
          print('Error decoding listing: $e');
        }
      }
    }
    return listings;
  }
  
  // ============= FAVORITES =============
  Future<void> toggleFavorite(String listingId) async {
    if (_favoritesBox.containsKey(listingId)) {
      await _favoritesBox.delete(listingId);
    } else {
      await _favoritesBox.put(listingId, listingId);
    }
  }
  
  bool isFavorite(String listingId) {
    return _favoritesBox.containsKey(listingId);
  }
  
  List<String> getFavoriteIds() {
    return _favoritesBox.values.toList();
  }
  
  // ============= USER DATA =============
  Future<void> saveUser(User user) async {
    await _userBox.put('current_user', jsonEncode(user.toJson()));
  }
  
  User? getCurrentUser() {
    final data = _userBox.get('current_user');
    if (data != null) {
      try {
        return User.fromJson(jsonDecode(data));
      } catch (e) {
        print('Error decoding user: $e');
      }
    }
    return null;
  }
  
  Future<void> clearUser() async {
    await _userBox.delete('current_user');
  }
}