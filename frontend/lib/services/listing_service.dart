// lib/services/listing_service.dart
import 'dart:convert';
import '../models/listing.dart';
import 'api_service.dart';

class ListingService {
  final ApiService _api = ApiService();

  // RENAME this from getListings to fetchListings
  Future<Map<String, dynamic>> fetchListings() async {
    try {
      final response = await _api.get('/listings');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Listing> listings = [];
        
        if (data['listings'] != null) {
          listings = (data['listings'] as List)
              .map((item) => Listing.fromJson(item))
              .toList();
        } else if (data is List) {
          listings = data.map((item) => Listing.fromJson(item)).toList();
        }
        
        return {
          'success': true,
          'listings': listings,
        };
      }
      
      return {
        'success': false,
          'error': 'Failed to load listings: ${response.statusCode}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getPopularListings() async {
    try {
      final response = await _api.get('/listings');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Listing> listings = [];
        
        if (data['listings'] != null) {
          listings = (data['listings'] as List)
              .map((item) => Listing.fromJson(item))
              .toList();
        } else if (data is List) {
          listings = data.map((item) => Listing.fromJson(item)).toList();
        }
        
        return {
          'success': true,
          'listings': listings,
        };
      }
      
      return {
        'success': false,
        'error': 'Failed to load popular listings',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getListingById(String id) async {
    try {
      final response = await _api.get('/listings/$id/complete');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'listing': Listing.fromJson(data['listing'] ?? data),
        };
      }
      
      return {
        'success': false,
        'error': 'Listing not found',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> createListing(Listing listing) async {
    try {
      final images = List<String>.from(
        listing.images ??
            (listing.imageUrl != null ? <String>[listing.imageUrl!] : const <String>[]),
      );
      final response = await _api.post('/listings', {
        'title': listing.title,
        'description': listing.description,
        'category': listing.category,
        'price': listing.price,
        'priceUnit': listing.priceUnit,
        'location': listing.location,
        'district': listing.district,
        'images': images,
        'additionalDetails': listing.additionalDetails,
      });

      final data = json.decode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        return {
          'success': true,
          'listing': Listing.fromJson(data['listing']),
        };
      }

      return {
        'success': false,
        'error': data['message'] ?? data['error'] ?? 'Failed to create listing',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> updateListing(Listing listing) async {
    try {
      final images = List<String>.from(
        listing.images ??
            (listing.imageUrl != null ? <String>[listing.imageUrl!] : const <String>[]),
      );
      final response = await _api.put('/listings/${listing.id}', {
        'title': listing.title,
        'description': listing.description,
        'category': listing.category,
        'price': listing.price,
        'priceUnit': listing.priceUnit,
        'location': listing.location,
        'district': listing.district,
        'images': images,
        'additionalDetails': listing.additionalDetails,
      });

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'listing': Listing.fromJson(data['listing']),
        };
      }

      return {
        'success': false,
        'error': data['message'] ?? data['error'] ?? 'Failed to update listing',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> deleteListing(String listingId) async {
    try {
      final response = await _api.delete('/listings/$listingId');
      final data = json.decode(response.body);

      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'error': data['message'] ?? data['error'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}
