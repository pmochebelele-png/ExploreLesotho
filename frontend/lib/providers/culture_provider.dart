import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/culture_subcategory.dart';
import '../models/culture_vendor.dart';
import '../services/cache_service.dart';
import '../services/culture_service.dart';

class CultureProvider extends ChangeNotifier {
  final CultureService _service = CultureService();

  List<CultureSubcategory> _subcategories = [];
  List<CultureVendor> _vendors = [];
  String _selectedSubcategorySlug = 'all';
  bool _isLoading = false;
  bool _isOfflineMode = false;
  DateTime? _lastSyncedAt;
  String? _error;
  CacheService? _cacheService;

  List<CultureSubcategory> get subcategories =>
      List.unmodifiable(_subcategories);
  List<CultureVendor> get vendors => List.unmodifiable(_vendors);
  String get selectedSubcategorySlug => _selectedSubcategorySlug;
  bool get isLoading => _isLoading;
  bool get isOfflineMode => _isOfflineMode;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get error => _error;

  Future<void> _initCache() async {
    final prefs = await SharedPreferences.getInstance();
    _cacheService = CacheService(prefs);
    _lastSyncedAt ??= _cacheService?.getCultureLastUpdated();
  }

  Future<void> loadInitial() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await _initCache();
    final subcategoryResult = await _service.fetchSubcategories();
    if (subcategoryResult['success'] == true) {
      final fetched = List<CultureSubcategory>.from(
          subcategoryResult['subcategories'] ?? []);
      // Hide Architecture from the culture chips per product decision.
      _subcategories =
          fetched.where((s) => s.slug.toLowerCase() != 'architecture').toList();
      _isOfflineMode = false;
      _lastSyncedAt = _cacheService?.getCultureLastUpdated();
    } else {
      final cached = await _cacheService?.loadCultureData() ?? {};
      final cachedSubcategories =
          List<CultureSubcategory>.from(cached['subcategories'] ?? const []);
      if (cachedSubcategories.isNotEmpty) {
        _subcategories = cachedSubcategories;
        _isOfflineMode = true;
        _error = 'Offline mode: showing cached culture data';
        _lastSyncedAt = _cacheService?.getCultureLastUpdated();
      } else {
        _error = subcategoryResult['error']?.toString() ??
            'Failed to load culture subcategories';
      }
    }

    await loadVendors();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadVendors({String? search}) async {
    await _initCache();
    final slug =
        _selectedSubcategorySlug == 'all' ? null : _selectedSubcategorySlug;
    final result =
        await _service.fetchVendors(subcategorySlug: slug, search: search);
    if (result['success'] == true) {
      _vendors = List<CultureVendor>.from(result['vendors'] ?? []);
      _error = null;
      _isOfflineMode = false;
      await _cacheService?.saveCultureData(
        subcategories: _subcategories,
        vendors: _vendors,
      );
      _lastSyncedAt = _cacheService?.getCultureLastUpdated();
    } else {
      final cached = await _cacheService?.loadCultureData() ?? {};
      final cachedVendors =
          List<CultureVendor>.from(cached['vendors'] ?? const []);
      if (cachedVendors.isNotEmpty) {
        _vendors = cachedVendors;
        _isOfflineMode = true;
        _error = 'Offline mode: showing cached culture vendors';
        _lastSyncedAt = _cacheService?.getCultureLastUpdated();
      } else {
        _vendors = [];
        _error = result['error']?.toString() ?? 'Failed to load culture vendors';
      }
    }
    notifyListeners();
  }

  Future<void> selectSubcategory(String slug) async {
    if (_selectedSubcategorySlug == slug) return;
    _selectedSubcategorySlug = slug;
    _isLoading = true;
    notifyListeners();
    await loadVendors();
    _isLoading = false;
    notifyListeners();
  }
}
