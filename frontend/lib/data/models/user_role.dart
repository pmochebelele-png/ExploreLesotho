// lib/data/models/user_role.dart
enum UserRole {
  tourist,
  vendor,
  admin;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'vendor':
        return UserRole.vendor;
      case 'tourist':
      default:
        return UserRole.tourist;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.vendor:
        return 'Service Provider';
      case UserRole.tourist:
        return 'Traveler';
    }
  }

  String get toLowerCase {
    return toString().split('.').last;
  }
}