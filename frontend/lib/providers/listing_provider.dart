// lib/providers/listing_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/tourism_seed_listings.dart';
import '../models/listing.dart';
import '../services/cache_service.dart';
import '../services/listing_service.dart';

class ListingProvider extends ChangeNotifier {
  final ListingService _listingService = ListingService();
  List<Listing> _listings = [];
  String _selectedCategory = 'All';
  String _selectedCultureType = 'All';
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isOfflineMode = false;
  DateTime? _lastSyncedAt;
  String? _error;
  CacheService? _cacheService;

  String _normalizeCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'cultural':
        return 'culture';
      default:
        return category.trim().toLowerCase();
    }
  }

  List<Listing> get listings {
    List<Listing> filtered = _listings;

    // Apply category filter
    if (_selectedCategory != 'All') {
      final selected = _normalizeCategory(_selectedCategory);
      filtered = filtered
          .where((l) => _normalizeCategory(l.category) == selected)
          .toList();
    }

    if (_normalizeCategory(_selectedCategory) == 'culture' &&
        _selectedCultureType != 'All') {
      final selectedCultureType = _selectedCultureType.trim().toLowerCase();
      filtered = filtered.where((l) {
        final listingCultureType = l.cultureType?.trim().toLowerCase();
        return listingCultureType != null &&
            listingCultureType == selectedCultureType;
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((l) =>
              l.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              l.description.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return filtered;
  }

  List<Listing> get allListings => List<Listing>.from(_listings);

  String get selectedCategory => _selectedCategory;
  String get selectedCultureType => _selectedCultureType;
  bool get isLoading => _isLoading;
  bool get isOfflineMode => _isOfflineMode;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get error => _error;

  List<String> get availableCultureTypes {
    final unique = <String>{};
    for (final listing in _listings) {
      if (_normalizeCategory(listing.category) != 'culture') continue;
      final type = listing.cultureType?.trim();
      if (type != null && type.isNotEmpty) {
        unique.add(type);
      }
    }
    final values = unique.toList()..sort();
    return values;
  }

  ListingProvider() {
    _initCache();
    loadListings();
  }

  Future<void> _initCache() async {
    final prefs = await SharedPreferences.getInstance();
    _cacheService = CacheService(prefs);
    _lastSyncedAt ??= _cacheService?.getListingsLastUpdated();
  }

  void _applyFetchResult(Map<String, dynamic> result) {
    if (result['success'] == true) {
      _listings = List<Listing>.from(result['listings'] ?? []);
      _mergeTourismSeedListings();
      _error = null;
      _isOfflineMode = false;
    } else {
      _error = result['error']?.toString() ?? 'Failed to load listings';
      _isOfflineMode = true;
    }
  }

  void _mergeTourismSeedListings() {
    final seenIds = _listings.map((listing) => listing.id).toSet();
    final seenTitles = _listings
        .map((listing) => listing.title.trim().toLowerCase())
        .where((title) => title.isNotEmpty)
        .toSet();

    final missingSeeds = TourismSeedListings.values.where((seed) {
      final title = seed.title.trim().toLowerCase();
      return !seenIds.contains(seed.id) && !seenTitles.contains(title);
    }).toList();

    if (missingSeeds.isNotEmpty) {
      _listings = [..._listings, ...missingSeeds];
    }
  }

  Future<void> loadListings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await _initCache();
    final result = await _listingService.fetchListings();
    if (result['success'] == true) {
      _applyFetchResult(result);
      await _cacheService?.saveListings(_listings);
      _lastSyncedAt = _cacheService?.getListingsLastUpdated();
    } else {
      final cachedListings = await _cacheService?.loadListings() ?? const [];
      if (cachedListings.isNotEmpty) {
        _listings = cachedListings;
        _mergeTourismSeedListings();
        _isOfflineMode = true;
        _error = 'Offline mode: showing cached listings';
        _lastSyncedAt = _cacheService?.getListingsLastUpdated();
      } else {
        _applyFetchResult(result);
        _listings = TourismSeedListings.values;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> syncListingsSilently() async {
    await _initCache();
    final result = await _listingService.fetchListings();
    if (result['success'] == true) {
      _applyFetchResult(result);
      await _cacheService?.saveListings(_listings);
      _lastSyncedAt = _cacheService?.getListingsLastUpdated();
    } else if (_listings.isEmpty) {
      final cachedListings = await _cacheService?.loadListings() ?? const [];
      if (cachedListings.isNotEmpty) {
        _listings = cachedListings;
        _mergeTourismSeedListings();
        _isOfflineMode = true;
        _lastSyncedAt = _cacheService?.getListingsLastUpdated();
      } else {
        _listings = TourismSeedListings.values;
        _isOfflineMode = true;
      }
    }
    notifyListeners();
  }

  // ✅ ADD THIS METHOD - Add a new listing
  Future<bool> addListing(Listing listing) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

      try {
        final result = await _listingService.createListing(listing);
        if (result['success'] == true && result['listing'] != null) {
          _listings.insert(0, result['listing'] as Listing);
          await _cacheService?.saveListings(_listings);
          _lastSyncedAt = _cacheService?.getListingsLastUpdated();
        } else {
        _error = result['error']?.toString() ?? 'Failed to create listing';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ ADD THIS METHOD - Update an existing listing
  Future<bool> updateListing(Listing listing) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

      try {
        final result = await _listingService.updateListing(listing);
        if (result['success'] == true && result['listing'] != null) {
          final updatedListing = result['listing'] as Listing;
          final index = _listings.indexWhere((l) => l.id == listing.id);
          if (index != -1) {
            _listings[index] = updatedListing;
          }
          await _cacheService?.saveListings(_listings);
          _lastSyncedAt = _cacheService?.getListingsLastUpdated();
          _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = result['error']?.toString() ?? 'Failed to update listing';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ ADD THIS METHOD - Delete a listing
  Future<bool> deleteListing(String listingId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

      try {
        final result = await _listingService.deleteListing(listingId);
        if (result['success'] == true) {
          _listings.removeWhere((l) => l.id == listingId);
          await _cacheService?.saveListings(_listings);
          _lastSyncedAt = _cacheService?.getListingsLastUpdated();
        } else {
        _error = result['error']?.toString() ?? 'Failed to delete listing';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ ADD THIS METHOD - Get listing by ID
  Listing? getListingById(String id) {
    try {
      return _listings.firstWhere((l) => l.id == id);
    } catch (e) {
      return null;
    }
  }

  // ✅ ADD THIS METHOD - Get listings by vendor ID
  List<Listing> getListingsByVendorId(String vendorId) {
    return _listings.where((l) => l.vendorId == vendorId).toList();
  }

  void filterByCategory(String category) {
    _selectedCategory = category;
    if (_normalizeCategory(category) != 'culture') {
      _selectedCultureType = 'All';
    }
    notifyListeners();
  }

  void filterByCultureType(String cultureType) {
    _selectedCultureType = cultureType;
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void refresh() {
    loadListings();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
