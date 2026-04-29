import 'dart:convert';

import '../models/culture_subcategory.dart';
import '../models/culture_vendor.dart';
import 'api_service.dart';

class CultureService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> fetchSubcategories() async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await _api.get('/culture/subcategories?ts=$ts');
      if (response.statusCode != 200) {
        return {
          'success': false,
          'error':
              'Failed to fetch culture subcategories: ${response.statusCode}',
        };
      }
      final data = json.decode(response.body);
      final subcategories = (data['subcategories'] as List? ?? const [])
          .map((item) => CultureSubcategory.fromJson(item))
          .toList();
      return {'success': true, 'subcategories': subcategories};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> fetchVendors({
    String? subcategorySlug,
    String? search,
  }) async {
    try {
      final params = <String>[];
      if ((subcategorySlug ?? '').trim().isNotEmpty) {
        params.add(
            'subcategory=${Uri.encodeQueryComponent(subcategorySlug!.trim())}');
      }
      if ((search ?? '').trim().isNotEmpty) {
        params.add('search=${Uri.encodeQueryComponent(search!.trim())}');
      }
      params.add('ts=${DateTime.now().millisecondsSinceEpoch}');
      final query = params.isEmpty ? '' : '?${params.join('&')}';
      final response = await _api.get('/culture/vendors$query');
      if (response.statusCode != 200) {
        return {
          'success': false,
          'error': 'Failed to fetch culture vendors: ${response.statusCode}',
        };
      }
      final data = json.decode(response.body);
      final vendors = (data['vendors'] as List? ?? const [])
          .map((item) => CultureVendor.fromJson(item))
          .toList();
      return {'success': true, 'vendors': vendors};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }
}
