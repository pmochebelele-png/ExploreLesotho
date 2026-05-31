// lib/models/user.dart
class User {
  final String id;
  final String name;
  final String email;
  final String role; // 'admin', 'vendor', 'tourist'
  final String? phone;
  final String? avatar;
  final String? createdAt;
  final bool isSuspended;
  final bool verified;
  final bool emailVerificationSent;
  final String? businessName;
  final String? businessType;
  final int? userId; // MySQL ID
  final String? linkedCultureVendorId;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.avatar,
    this.createdAt,
    this.isSuspended = false,
    this.verified = false,
    this.emailVerificationSent = false,
    this.businessName,
    this.businessType,
    this.userId,
    this.linkedCultureVendorId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id']?.toString() ??
          json['id']?.toString() ??
          json['_id']?.toString() ??
          '',
      userId: json['user_id'],
      name: json['full_name'] ?? json['name'] ?? json['fullName'] ?? 'Unknown',
      email: json['email'] ?? '',
      role: json['role']?.toString().toLowerCase() ?? 'tourist',
      phone: json['phone'],
      avatar: json['avatar'] ?? json['profileImage'],
      createdAt: json['created_at'] ?? json['createdAt'],
      isSuspended: json['suspended'] == 1 || json['isSuspended'] == true,
      verified: json['verified'] == 1 || json['verified'] == true,
      emailVerificationSent: json['emailVerificationSent'] == true,
      businessName: json['business_name'] ?? json['businessName'],
      businessType: json['business_type'] ?? json['businessType'],
      linkedCultureVendorId: json['linkedCultureVendorId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId ?? id,
      'full_name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'avatar': avatar,
      'created_at': createdAt,
      'suspended': isSuspended ? 1 : 0,
      'verified': verified ? 1 : 0,
      'emailVerificationSent': emailVerificationSent,
      'business_name': businessName,
      'business_type': businessType,
      'linkedCultureVendorId': linkedCultureVendorId,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? phone,
    String? avatar,
    String? createdAt,
    bool? isSuspended,
    bool? verified,
    bool? emailVerificationSent,
    String? businessName,
    String? businessType,
    int? userId,
    String? linkedCultureVendorId,
  }) {
    return User(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
      isSuspended: isSuspended ?? this.isSuspended,
      verified: verified ?? this.verified,
      emailVerificationSent:
          emailVerificationSent ?? this.emailVerificationSent,
      businessName: businessName ?? this.businessName,
      businessType: businessType ?? this.businessType,
      linkedCultureVendorId:
          linkedCultureVendorId ?? this.linkedCultureVendorId,
    );
  }

  // Helper getters
  bool get isAdmin => role == 'admin';
  bool get isVendor => role == 'vendor';
  bool get isTourist => role == 'tourist';
  bool get isPendingVendor => isVendor && !verified;
}
