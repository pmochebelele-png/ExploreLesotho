// lib/models/listing.dart
import 'dart:convert';

class Listing {
  final String id;
  final String title;
  final String description;
  final String category;
  final double price;
  final String? priceUnit;
  final String location;
  final String? district;
  final double? rating;
  final int? reviewCount;
  final String? imageUrl;
  final bool isFeatured;
  final bool isAvailable;
  final bool? isFavorite;
  final String? categoryIcon;
  final List<String>? images;
  final Map<String, dynamic>? additionalDetails;
  final String? vendorId;
  final String? vendorName;

  // Vendor Contact Fields
  final String? vendorPhone;
  final String? vendorEmail;
  final String? vendorWebsite;
  final String? vendorFacebook;
  final String? vendorInstagram;
  final String? vendorWhatsapp;

  Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    this.priceUnit,
    required this.location,
    this.district,
    this.rating,
    this.reviewCount,
    this.imageUrl,
    this.isFeatured = false,
    this.isAvailable = true,
    this.isFavorite,
    this.categoryIcon,
    this.images,
    this.additionalDetails,
    this.vendorId,
    this.vendorName,
    this.vendorPhone,
    this.vendorEmail,
    this.vendorWebsite,
    this.vendorFacebook,
    this.vendorInstagram,
    this.vendorWhatsapp,
  });

  String get formattedPrice {
    if (price == 0) return 'Free';
    return 'M${price.toStringAsFixed(0)}';
  }

  String? get cultureType {
    if (category.trim().toLowerCase() != 'culture') return null;
    final rawType = additionalDetails?['cultureType']
        ?.toString()
        .replaceAll(RegExp(r'[\[\]"]'), '')
        .trim();
    if (rawType != null && rawType.isNotEmpty) return rawType;
    final rawFocus = additionalDetails?['heritageFocus']
        ?.toString()
        .replaceAll(RegExp(r'[\[\]"]'), '')
        .trim();
    if (rawFocus == null || rawFocus.isEmpty) return null;
    final first = rawFocus.split(',').first.trim();
    return first.isEmpty ? null : first;
  }

  double? _parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  double? get latitude {
    return _parseCoordinate(
      additionalDetails?['latitude'] ??
          additionalDetails?['lat'] ??
          additionalDetails?['mapLatitude'] ??
          additionalDetails?['locationLatitude'],
    );
  }

  double? get longitude {
    return _parseCoordinate(
      additionalDetails?['longitude'] ??
          additionalDetails?['lng'] ??
          additionalDetails?['lon'] ??
          additionalDetails?['mapLongitude'] ??
          additionalDetails?['locationLongitude'],
    );
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  static double _parsePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) {
      final cleaned = price.replaceAll(RegExp(r'[^\d.-]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  factory Listing.fromJson(Map<String, dynamic> json) {
    final parsedAdditionalDetails = (() {
      final rawDetails =
          json['additionalDetails'] ?? json['additional_details'];
      if (rawDetails == null) return null;
      if (rawDetails is Map<String, dynamic>) return rawDetails;
      if (rawDetails is Map) {
        return rawDetails.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
      if (rawDetails is String) {
        final trimmed = rawDetails.trim();
        if (trimmed.isEmpty) return null;
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map<String, dynamic>) return decoded;
          if (decoded is Map) {
            return decoded.map(
              (key, value) => MapEntry(key.toString(), value),
            );
          }
        } catch (_) {
          return null;
        }
      }
      return null;
    })();

    final parsedImages = (() {
      final rawImages = json['images'];
      if (rawImages == null) return null;
      if (rawImages is List) {
        return rawImages
            .map((item) => item?.toString() ?? '')
            .where((item) => item.isNotEmpty)
            .toList();
      }
      if (rawImages is String) {
        final trimmed = rawImages.trim();
        if (trimmed.isEmpty) return null;
        if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
          try {
            return (jsonDecode(trimmed) as List)
                .map((item) => item.toString())
                .where((item) => item.isNotEmpty)
                .toList();
          } catch (_) {
            return [trimmed];
          }
        }
        return [trimmed];
      }
      return null;
    })();

    return Listing(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title'] ?? json['name'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'Accommodation',
      location: json['location'] ?? json['area'] ?? '',
      district: json['district'] ?? json['region'],
      price: _parsePrice(json['price']),
      priceUnit: json['priceUnit'] ?? json['unit'],
      rating: json['rating'] != null
          ? (json['rating'] is double
              ? json['rating']
              : double.tryParse(json['rating'].toString()) ?? 0.0)
          : null,
      reviewCount: json['reviewCount'] != null
          ? (json['reviewCount'] is int
              ? json['reviewCount']
              : int.tryParse(json['reviewCount'].toString()) ?? 0)
          : (json['reviews'] != null ? (json['reviews'] as List).length : null),
      imageUrl: json['imageUrl'] ??
          json['image'] ??
          (parsedImages != null && parsedImages.isNotEmpty
              ? parsedImages.first
              : null),
      isFeatured: json['isFeatured'] ?? false,
      isAvailable: json['isAvailable'] ?? true,
      isFavorite: json['isFavorite'],
      categoryIcon: json['categoryIcon'],
      images: parsedImages,
      additionalDetails: parsedAdditionalDetails,
      vendorId: json['vendorId']?.toString() ?? json['vendor_id']?.toString(),
      vendorName: json['vendorName'] ?? json['vendor_name'],
      vendorPhone:
          json['vendorPhone'] ?? json['vendor_phone'] ?? json['business_phone'],
      vendorEmail:
          json['vendorEmail'] ?? json['vendor_email'] ?? json['business_email'],
      vendorWebsite:
          json['vendorWebsite'] ?? json['vendor_website'] ?? json['website'],
      vendorFacebook:
          json['vendorFacebook'] ?? json['vendor_facebook'] ?? json['facebook'],
      vendorInstagram: json['vendorInstagram'] ??
          json['vendor_instagram'] ??
          json['instagram'],
      vendorWhatsapp:
          json['vendorWhatsapp'] ?? json['vendor_whatsapp'] ?? json['whatsapp'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'priceUnit': priceUnit,
      'location': location,
      'district': district,
      'rating': rating,
      'reviewCount': reviewCount,
      'imageUrl': imageUrl,
      'isFeatured': isFeatured,
      'isAvailable': isAvailable,
      'isFavorite': isFavorite,
      'categoryIcon': categoryIcon,
      'images': images,
      'additionalDetails': additionalDetails,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'vendorPhone': vendorPhone,
      'vendorEmail': vendorEmail,
      'vendorWebsite': vendorWebsite,
      'vendorFacebook': vendorFacebook,
      'vendorInstagram': vendorInstagram,
      'vendorWhatsapp': vendorWhatsapp,
    };
  }
}
