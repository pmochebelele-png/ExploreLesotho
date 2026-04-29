// lib/data/providers/vendor_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/booking.dart';
import '../models/vendor.dart';

class VendorProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  Map<String, dynamic>? _vendor;
  List<Booking> _bookings = [];
  List<dynamic> _listings = [];
  List<Vendor> _vendors = [];

  bool get isLoading => _isLoading;
  Map<String, dynamic>? get vendor => _vendor;
  List<Booking> get bookings => _bookings;
  List<dynamic> get listings => _listings;
  List<Vendor> get vendors => _vendors;

  VendorProvider();

  // Fetch vendor data from API
  Future<void> fetchVendorData(String vendorId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Fetch Vendor Profile (MySQL)
      final profileRes = await _apiService.get('/vendors/$vendorId');

      // 2. Fetch Vendor Bookings
      final bookingsRes = await _apiService.get('/bookings/vendor/$vendorId');

      // 3. Fetch Listings
      final listingsRes = await _apiService.get('/listings/vendor/$vendorId');

      if (profileRes.statusCode == 200) {
        final data = json.decode(profileRes.body);
        _vendor = data['vendor'] ?? data;
      }

      if (bookingsRes.statusCode == 200) {
        final data = json.decode(bookingsRes.body);
        final List<dynamic> bookingData = data['bookings'] ?? [];

        _bookings = bookingData.map<Booking>((item) {
          return Booking.fromJson(item as Map<String, dynamic>);
        }).toList();
      }

      if (listingsRes.statusCode == 200) {
        final data = json.decode(listingsRes.body);
        _listings = data['listings'] ?? data;
      }
    } catch (e) {
      debugPrint("❌ Provider Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh vendor data
  void refresh() {
    final id = _vendor?['vendor_id'] ?? _vendor?['id'];
    if (id != null) {
      fetchVendorData(id.toString());
    } else {
      _vendors = [];
      notifyListeners();
    }
  }

  // Update booking status
  Future<bool> updateBookingStatus(int bookingId, String status) async {
    try {
      final response = await _apiService
          .put('/bookings/$bookingId/status', {'status': status});

      if (response.statusCode == 200) {
        refresh();
        return true;
      }
    } catch (e) {
      debugPrint("Error updating booking: $e");
    }
    return false;
  }

  Vendor? getVendorById(String id) {
    try {
      return _vendors.firstWhere((v) => v.id.toString() == id);
    } catch (e) {
      return null;
    }
  }

  List<Vendor> getVerifiedVendors() {
    return _vendors.where((v) => v.isVerified).toList();
  }

  List<Vendor> getPendingVendors() {
    return _vendors.where((v) => !v.isVerified).toList();
  }

  Future<bool> approveVendor(String vendorId) async {
    return false;
  }

  Future<bool> rejectVendor(String vendorId) async {
    return false;
  }

  Future<bool> addVendor(Vendor vendor) async {
    return false;
  }

  Future<bool> updateVendor(Vendor vendor) async {
    return false;
  }
}

