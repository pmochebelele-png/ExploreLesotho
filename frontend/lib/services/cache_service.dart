
// lib/services/cache_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/culture_subcategory.dart';
import '../models/culture_vendor.dart';
import '../models/event.dart';
import '../models/listing.dart';

class CacheService {
  static const String _listingsKey = 'cached_listings';
  static const String _cultureSubcategoriesKey = 'cached_culture_subcategories';
  static const String _cultureVendorsKey = 'cached_culture_vendors';
  static const String _upcomingEventsKey = 'cached_upcoming_events';
  static const String _lastUpdatedKey = 'last_updated';
  static const String _cultureLastUpdatedKey = 'culture_last_updated';
  static const String _eventsLastUpdatedKey = 'events_last_updated';
  static const Duration _cacheDuration = Duration(days: 7); // Cache expires after 7 days

  final SharedPreferences _prefs;

  CacheService(this._prefs);

  // Save listings to cache
  Future<void> saveListings(List<Listing> listings) async {
    try {
      final listingsJson = listings.map((l) => l.toJson()).toList();
      await _prefs.setString(_listingsKey, json.encode(listingsJson));
      await _prefs.setString(_lastUpdatedKey, DateTime.now().toIso8601String());
      print('✅ Listings cached: ${listings.length} items');
    } catch (e) {
      print('❌ Failed to cache listings: $e');
    }
  }

  Future<void> saveCultureData({
    required List<CultureSubcategory> subcategories,
    required List<CultureVendor> vendors,
  }) async {
    try {
      await _prefs.setString(
        _cultureSubcategoriesKey,
        json.encode(subcategories.map((item) => item.toJson()).toList()),
      );
      await _prefs.setString(
        _cultureVendorsKey,
        json.encode(vendors.map((item) => item.toJson()).toList()),
      );
      await _prefs.setString(
        _cultureLastUpdatedKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      print('❌ Failed to cache culture data: $e');
    }
  }

  Future<Map<String, dynamic>> loadCultureData() async {
    try {
      final subcategoriesRaw = _prefs.getString(_cultureSubcategoriesKey);
      final vendorsRaw = _prefs.getString(_cultureVendorsKey);
      final subcategories = subcategoriesRaw == null
          ? <CultureSubcategory>[]
          : (json.decode(subcategoriesRaw) as List)
              .map((item) => CultureSubcategory.fromJson(item))
              .toList();
      final vendors = vendorsRaw == null
          ? <CultureVendor>[]
          : (json.decode(vendorsRaw) as List)
              .map((item) => CultureVendor.fromJson(item))
              .toList();
      return {
        'subcategories': subcategories,
        'vendors': vendors,
      };
    } catch (e) {
      print('❌ Failed to load cached culture data: $e');
      return {
        'subcategories': <CultureSubcategory>[],
        'vendors': <CultureVendor>[],
      };
    }
  }

  Future<void> saveUpcomingEvents(List<Event> events) async {
    try {
      await _prefs.setString(
        _upcomingEventsKey,
        json.encode(events.map((item) => item.toJson()).toList()),
      );
      await _prefs.setString(
        _eventsLastUpdatedKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      print('❌ Failed to cache upcoming events: $e');
    }
  }

  Future<List<Event>> loadUpcomingEvents() async {
    try {
      final raw = _prefs.getString(_upcomingEventsKey);
      if (raw == null) return [];
      return (json.decode(raw) as List)
          .map((item) => Event.fromJson(item))
          .toList();
    } catch (e) {
      print('❌ Failed to load cached upcoming events: $e');
      return [];
    }
  }

  // Load listings from cache
  Future<List<Listing>> loadListings() async {
    try {
      final listingsJsonString = _prefs.getString(_listingsKey);
      if (listingsJsonString == null) {
        print('📦 No cached listings found');
        return [];
      }

      final List<dynamic> listingsJson = json.decode(listingsJsonString);
      final listings = listingsJson.map((json) => Listing.fromJson(json)).toList();
      print('📦 Loaded ${listings.length} listings from cache');
      return listings;
    } catch (e) {
      print('❌ Failed to load cached listings: $e');
      return [];
    }
  }

  // Check if cache is valid (not expired)
  Future<bool> isCacheValid() async {
    final lastUpdatedStr = _prefs.getString(_lastUpdatedKey);
    if (lastUpdatedStr == null) return false;

    try {
      final lastUpdated = DateTime.parse(lastUpdatedStr);
      final isExpired = DateTime.now().difference(lastUpdated) > _cacheDuration;
      return !isExpired;
    } catch (e) {
      return false;
    }
  }

  // Check if cache exists
  Future<bool> hasCache() async {
    return _prefs.containsKey(_listingsKey);
  }

  // Clear cache
  Future<void> clearCache() async {
    await _prefs.remove(_listingsKey);
    await _prefs.remove(_lastUpdatedKey);
    print('🗑️ Cache cleared');
  }

  // Get cache info (for debugging)
  Future<Map<String, dynamic>> getCacheInfo() async {
    final hasCache = await this.hasCache();
    final isValid = await isCacheValid();
    final lastUpdatedStr = _prefs.getString(_lastUpdatedKey);
    
    return {
      'hasCache': hasCache,
      'isValid': isValid,
      'lastUpdated': lastUpdatedStr,
      'cacheDuration': _cacheDuration.inDays,
    };
  }

  DateTime? getListingsLastUpdated() {
    final raw = _prefs.getString(_lastUpdatedKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  DateTime? getCultureLastUpdated() {
    final raw = _prefs.getString(_cultureLastUpdatedKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  DateTime? getEventsLastUpdated() {
    final raw = _prefs.getString(_eventsLastUpdatedKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }
}
