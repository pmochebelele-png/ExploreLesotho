// lib/data/models/vendor.dart
class Vendor {
  final int id;
  final int userId;
  final String businessName;
  final String? businessEmail;
  final String? businessPhone;
  final String? businessType;
  final String? businessAddress;
  final bool isVerified;
  final bool isActive;
  final String status;
  final int totalBookings;
  final double totalRevenue;
  final double averageRating;
  final DateTime joinedAt;
  final String? logo;
  final String? description;
  final String ownerName;
  final String ownerEmail;
  final String? whatsapp;
  final String? facebook;
  final String? instagram;
  final String? twitter;
  final String? website;

  Vendor({
    required this.id,
    required this.userId,
    required this.businessName,
    this.businessEmail,
    this.businessPhone,
    this.businessType,
    this.businessAddress,
    required this.isVerified,
    this.isActive = true,
    this.status = 'pending',
    this.totalBookings = 0,
    this.totalRevenue = 0,
    this.averageRating = 0,
    required this.joinedAt,
    this.logo,
    this.description,
    required this.ownerName,
    required this.ownerEmail,
    this.whatsapp,
    this.facebook,
    this.instagram,
    this.twitter,
    this.website,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'] ?? json['vendor_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      businessName: json['business_name'] ?? json['businessName'] ?? 'Unknown Business',
      businessEmail: json['business_email'] ?? json['businessEmail'],
      businessPhone: json['business_phone'] ?? json['businessPhone'],
      businessType: json['business_type'] ?? json['businessType'],
      businessAddress: json['business_address'] ?? json['businessAddress'],
      isVerified: (json['verified'] == 1 || json['verified'] == true),
      isActive: json['status'] == 'active',
      status: json['status'] ?? 'pending',
      totalBookings: json['totalBookings'] ?? json['total_bookings'] ?? 0,
      totalRevenue: (json['totalRevenue'] ?? json['total_revenue'] ?? 0).toDouble(),
      averageRating: (json['averageRating'] ?? json['average_rating'] ?? 0).toDouble(),
      joinedAt: DateTime.tryParse(
            (json['joinedAt'] ??
                    json['joined_at'] ??
                    json['createdAt'] ??
                    json['created_at'] ??
                    '')
                .toString(),
          ) ??
          DateTime.now(),
      logo: json['logo'],
      description: json['description'],
      ownerName: json['ownerName'] ?? json['full_name'] ?? 'Unknown',
      ownerEmail: json['ownerEmail'] ?? json['email'] ?? '',
      whatsapp: json['whatsapp'],
      facebook: json['facebook'],
      instagram: json['instagram'],
      twitter: json['twitter'],
      website: json['website'],
    );
  }

  bool get isPending => status == 'pending' && !isVerified;
  bool get isActiveVendor => status == 'active' && isVerified;
  bool get isSuspended => status == 'suspended';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'business_name': businessName,
      'business_email': businessEmail,
      'business_phone': businessPhone,
      'business_type': businessType,
      'business_address': businessAddress,
      'verified': isVerified ? 1 : 0,
      'status': status,
      'joinedAt': joinedAt.toIso8601String(),
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'whatsapp': whatsapp,
      'facebook': facebook,
      'instagram': instagram,
      'twitter': twitter,
      'website': website,
    };
  }
}
