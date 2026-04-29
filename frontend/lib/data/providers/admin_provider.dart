// lib/data/providers/admin_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../models/vendor.dart';
import '../../models/review.dart';

class AdminProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  List<User> _users = [];
  List<Vendor> _vendors = [];
  List<Review> _reviews = [];
  Map<String, dynamic> _liveStats = {};

  bool get isLoading => _isLoading;
  
  List<User> get users {
    print('📊 users getter called - returning ${_users.length} users');
    return _users;
  }
  
  List<Vendor> get vendors {
    print('📊 vendors getter called - returning ${_vendors.length} vendors');
    return List<Vendor>.from(_vendors);
  }
  
  List<Review> get reviews => _reviews;

  AdminProvider();

  void refresh() => fetchAllAdminData();

  Future<void> fetchAllAdminData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await fetchUsers();
      await fetchPlatformStats();
      await fetchVendors();
      await fetchReviewsSafe();
    } catch (e) {
      debugPrint("❌ Admin Sync Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> getPlatformStats() {
    return {
      'totalUsers': _liveStats['totalUsers'] ?? _users.length,
      'totalVendors': _liveStats['totalVendors'] ?? _vendors.length,
      'totalBookings': _liveStats['totalBookings'] ?? 0,
      'totalRevenue': _liveStats['totalRevenue'] ?? 0.0,
      'pendingVendors': _liveStats['pendingVendors'] ?? _vendors.where((vendor) => !vendor.isVerified).length,
      'pendingReviews': 0,
    };
  }

  Future<void> fetchUsers() async {
    try {
      print('🔄 Fetching users...');
      final res = await _apiService.get('/admin/users/all');
      print('📡 Users Response Status: ${res.statusCode}');

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = data['users'] ?? [];
        print('📊 Found ${list.length} users');

        _users = (list as List)
            .map((u) {
              print('   User: ${u['full_name']} (${u['role']})');
              return User.fromJson(u);
            })
            .toList();
        print('✅ Loaded ${_users.length} users successfully');
      } else {
        print('❌ Failed to load users: ${res.statusCode}');
        _users = [];
      }
    } catch (e) {
      debugPrint("❌ fetchUsers error: $e");
      _users = [];
    }
    notifyListeners();
  }

  Future<void> fetchVendors() async {
    try {
      print('🔄 FETCHING VENDORS...');
      final res = await _apiService.get('/admin/vendors/all?t=${DateTime.now().millisecondsSinceEpoch}');
      print('📡 STATUS: ${res.statusCode}');
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        print('📡 PARSED DATA SUCCESS: ${data['success']}');
        
        if (data['success'] == true) {
          final vendorsList = data['vendors'] ?? [];
          print('📊 VENDORS COUNT FROM API: ${vendorsList.length}');
          
          if (vendorsList.isEmpty) {
            print('⚠️ No vendors found in response');
            _vendors = [];
          } else {
            _vendors = [];
            
            for (var v in vendorsList) {
              print('   → Processing vendor: ${v['business_name'] ?? 'UNKNOWN'}');
              try {
                final vendor = Vendor.fromJson(v);
                _vendors.add(vendor);
                print('   ✅ Added: ${vendor.businessName}');
              } catch (e) {
                print('   ❌ Failed to parse vendor: $e');
              }
            }
            
            print('✅ Loaded ${_vendors.length} vendors successfully');
            print('📊 Vendors in memory: ${_vendors.map((v) => v.businessName).join(', ')}');
          }
        } else {
          print('❌ Success false: ${data['message']}');
          _vendors = [];
        }
      } else {
        print('❌ HTTP Error: ${res.statusCode}');
        _vendors = [];
      }
    } catch (e) {
      print('❌ FETCH VENDORS EXCEPTION: $e');
      _vendors = [];
    }
    notifyListeners();
    print('📢 notifyListeners called - vendors count: ${_vendors.length}');
  }

  Future<void> fetchReviews() async {
    try {
      print('🔄 FETCHING REVIEWS...');
      // Add cache-busting timestamp
      final res = await _apiService.get('/admin/reviews?t=${DateTime.now().millisecondsSinceEpoch}');
      print('📡 Reviews Response Status: ${res.statusCode}');
      print('📡 Reviews Response Body: ${res.body}');
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        print('📡 PARSED DATA SUCCESS: ${data['success']}');
        print('📡 REVIEWS COUNT FROM API: ${data['reviews']?.length ?? 0}');
        
        if (data['success'] == true) {
          final reviewsList = data['reviews'] ?? [];
          print('📊 Found ${reviewsList.length} reviews');
          
          if (reviewsList.isEmpty) {
            print('⚠️ No reviews found');
            _reviews = [];
          } else {
            if (reviewsList.isNotEmpty) {
              print('📦 First review raw data: ${reviewsList[0]}');
            }
            
            _reviews = reviewsList.map((r) {
              final commentPreview = r['comment'] != null 
                  ? (r['comment'].length > 30 ? '${r['comment'].substring(0, 30)}...' : r['comment'])
                  : 'No comment';
              print('   → Processing review: $commentPreview (Status: ${r['status']})');
              return Review.fromJson(r);
            }).toList();
            
            print('✅ Loaded ${_reviews.length} reviews successfully');
            print('📊 Reviews loaded: ${_reviews.length}');
          }
        } else {
          print('❌ Failed to load reviews: ${data['message']}');
          _reviews = [];
        }
      } else {
        print('❌ HTTP Error: ${res.statusCode}');
        _reviews = [];
      }
    } catch (e) {
      print('❌ fetchReviews error: $e');
      print('   Stack trace: ${StackTrace.current}');
      _reviews = [];
    }
    notifyListeners();
  }

  Future<void> fetchPlatformStats() async {
    try {
      print('🔄 Fetching platform stats...');
      final res = await _apiService.get('/admin/stats');
      print('📡 Stats Response Status: ${res.statusCode}');
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _liveStats = data['stats'] ?? {};
        print('✅ Stats loaded: totalUsers=${_liveStats['totalUsers']}, totalVendors=${_liveStats['totalVendors']}');
      } else {
        print('❌ Failed to load stats: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint("❌ fetchPlatformStats error: $e");
    }
    notifyListeners();
  }

  // ============================================
  // USER MANAGEMENT ACTIONS
  // ============================================

  Future<bool> createUser(Map<String, dynamic> userData) async {
    try {
      print('📝 Creating user: $userData');
      final res = await _apiService.post('/admin/users', userData);
      print('📡 Create User Response Status: ${res.statusCode}');
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          print('✅ User created successfully');
          await fetchUsers();
          return true;
        } else {
          print('❌ Failed to create user: ${data['message']}');
        }
      }
      return false;
    } catch (e) {
      debugPrint("❌ createUser error: $e");
      return false;
    }
  }

  Future<bool> updateUser(String userId, Map<String, dynamic> userData) async {
    try {
      print('📝 Updating user $userId: $userData');
      final res = await _apiService.put('/admin/users/$userId', userData);
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          print('✅ User updated successfully');
          await fetchUsers();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("❌ updateUser error: $e");
      return false;
    }
  }

  Future<bool> deleteUser(dynamic userId) async {
    try {
      print('🗑️ Deleting user: $userId');
      final res = await _apiService.delete('/admin/users/$userId');

      if (res.statusCode == 200) {
        _users.removeWhere((u) => u.id == userId.toString());
        notifyListeners();
        print('✅ User deleted successfully');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Delete User Error: $e");
      return false;
    }
  }

  Future<bool> suspendUser(dynamic userId) async {
    try {
      print('🔒 Suspending user: $userId');
      final res = await _apiService.patch('/admin/users/$userId/suspend', {
        'suspended': true
      });

      if (res.statusCode == 200) {
        final index = _users.indexWhere((u) => u.id == userId.toString());
        if (index != -1) {
          _users[index] = _users[index].copyWith(isSuspended: true);
          notifyListeners();
        }
        print('✅ User suspended successfully');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Suspend User Error: $e");
      return false;
    }
  }

  Future<bool> activateUser(dynamic userId) async {
    try {
      print('🔓 Activating user: $userId');
      final res = await _apiService.patch('/admin/users/$userId/suspend', {
        'suspended': false
      });

      if (res.statusCode == 200) {
        final index = _users.indexWhere((u) => u.id == userId.toString());
        if (index != -1) {
          _users[index] = _users[index].copyWith(isSuspended: false);
          notifyListeners();
        }
        print('✅ User activated successfully');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Activate User Error: $e");
      return false;
    }
  }

  // ============================================
  // VENDOR MANAGEMENT ACTIONS
  // ============================================

  Future<bool> approveVendor(dynamic vendorId) async {
    try {
      print('✅ Approving vendor: $vendorId');
      final res = await _apiService.patch('/admin/vendors/$vendorId/verify', {});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          print('✅ Vendor approved successfully');
          refresh();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("❌ approveVendor error: $e");
      return false;
    }
  }

  Future<bool> rejectVendor(dynamic vendorId) async {
    try {
      print('❌ Rejecting vendor: $vendorId');
      final res = await _apiService.patch('/admin/vendors/$vendorId/reject', {});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          print('✅ Vendor rejected successfully');
          refresh();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("❌ rejectVendor error: $e");
      return false;
    }
  }

  Future<void> fetchReviewsSafe() async {
    try {
      final res = await _apiService
          .get('/admin/reviews?t=${DateTime.now().millisecondsSinceEpoch}');

      if (res.statusCode != 200) {
        _reviews = [];
        notifyListeners();
        return;
      }

      final data = json.decode(res.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        _reviews = [];
        notifyListeners();
        return;
      }

      final reviewsJson = List<Map<String, dynamic>>.from(
        (data['reviews'] as List?) ?? const [],
      );

      final parsed = <Review>[];
      for (final item in reviewsJson) {
        try {
          parsed.add(Review.fromJson(item));
        } catch (e) {
          debugPrint('Skipping bad admin review row: $e');
        }
      }

      _reviews = parsed;
    } catch (e) {
      debugPrint('fetchReviewsSafe error: $e');
      _reviews = [];
    }

    notifyListeners();
  }
}
