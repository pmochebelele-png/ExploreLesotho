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

  bool _isLegacyGoogleHotel(Listing listing) {
    final id = listing.id.trim().toLowerCase();
    if (id.startsWith('map-hotel-') || id.startsWith('google-')) {
      return true;
    }

    final source =
        listing.additionalDetails?['source']?.toString().toLowerCase();
    final sourceLabel =
        listing.additionalDetails?['sourceLabel']?.toString().toLowerCase();
    if (source == 'google_places' ||
        sourceLabel == 'google places' ||
        sourceLabel == 'maseru hotel map') {
      return true;
    }

    const legacyHotelTitles = {
      'noble hearts bed & breakfast',
      'foothills guesthouse',
      'mpilo boutique hotel',
      'city stay west',
      'denver echo executive guesthouse',
      'seilatsatsi b&b',
      'scenery guest house maqilika',
      'scenery guest house maqalika',
      'lakeside hotel',
      'mohalalitoe bed & breakfast',
      'my kasi home bnb',
      'taung guesthouse',
      'city stay maseru',
      'thabeng hotel & restaurant',
      'jate guest house',
      'the anne guest house',
      'khali hotel',
      'mohokare guest house',
      'lancer\'s inn hotel maseru',
      'avani maseru hotel',
      'hokahanya inn & conference centre',
      'hokahanya inn & c...',
      'the mon bnb',
    };
    final title = listing.title.trim().toLowerCase();
    if (source == 'fallback' &&
        _normalizeCategory(listing.category) == 'accommodation') {
      return legacyHotelTitles.any((legacyTitle) =>
          title == legacyTitle ||
          title.startsWith(legacyTitle.replaceAll('...', '').trim()));
    }

    return legacyHotelTitles.any((legacyTitle) =>
        title == legacyTitle ||
        title.startsWith(legacyTitle.replaceAll('...', '').trim()));
  }

  List<Listing> _withoutLegacyGoogleHotels(Iterable<Listing> listings) {
    return listings.where((listing) => !_isLegacyGoogleHotel(listing)).toList();
  }

  List<Listing> get listings {
    List<Listing> filtered = _withoutLegacyGoogleHotels(_listings);

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

  double _fameScore(Listing listing) {
    final ratingScore = (listing.rating ?? 0) * 20;
    final reviewScore =
        (listing.reviewCount ?? 0).clamp(0, 500).toDouble() / 10;
    final featuredScore = listing.isFeatured ? 40 : 0;
    final availabilityScore = listing.isAvailable ? 8 : 0;
    return featuredScore + ratingScore + reviewScore + availabilityScore;
  }

  List<Listing> topFamousListings({int limit = 10}) {
    final sourceListings = _withoutLegacyGoogleHotels(_listings);
    final available =
        sourceListings.where((listing) => listing.isAvailable).toList();
    final ranked =
        available.isNotEmpty ? available : List<Listing>.from(sourceListings);
    ranked.sort((a, b) => _fameScore(b).compareTo(_fameScore(a)));

    final selected = <Listing>[];
    final usedIds = <String>{};
    final categories = <String>[
      'Accommodation',
      'Tour',
      'Experience',
      'Culture',
      'Adventure',
    ];

    for (final category in categories) {
      for (final listing in ranked) {
        if (_normalizeCategory(listing.category) ==
                _normalizeCategory(category) &&
            !usedIds.contains(listing.id)) {
          selected.add(listing);
          usedIds.add(listing.id);
          break;
        }
      }
    }

    for (final listing in ranked) {
      if (selected.length >= limit) break;
      if (usedIds.add(listing.id)) {
        selected.add(listing);
      }
    }

    return selected.take(limit).toList();
  }

  List<Listing> get allListings => _withoutLegacyGoogleHotels(_listings);

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
      _listings = _withoutLegacyGoogleHotels(
        List<Listing>.from(result['listings'] ?? []),
      );
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
        _listings = _withoutLegacyGoogleHotels(cachedListings);
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
        _listings = _withoutLegacyGoogleHotels(cachedListings);
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
