// lib/providers/dev_auth_provider.dart
import 'package:flutter/material.dart';
import '../models/user.dart';

class DevAuthProvider extends ChangeNotifier {
  User? _user;
  String? _selectedRole = 'admin';

  User? get user => _user;
  String? get selectedRole => _selectedRole;
  bool get isAdmin => _user?.role == 'admin';
  bool get isVendor => _user?.role == 'vendor';
  bool get isTourist => _user?.role == 'tourist';

  DevAuthProvider() {
    _loginAs('admin');
  }

  void _loginAs(String role) {
    _selectedRole = role;
    _user = User(
      id: 'dev-user-id',
      name: 'Dev ${role[0].toUpperCase()}${role.substring(1)}',
      email: '$role@example.com',
      role: role,
    );
    notifyListeners();
  }

  void switchToAdmin() {
    _loginAs('admin');
  }

  void switchToVendor() {
    _loginAs('vendor');
  }

  void switchToTourist() {
    _loginAs('tourist');
  }

  void logout() {
    _user = null;
    notifyListeners();
  }

  // ✅ ADD THIS METHOD
  Future<String?> getToken() async {
    // Return a mock token for development
    return 'dev-mock-token-12345';
  }
}