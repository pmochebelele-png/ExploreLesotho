import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../admin/admin_dashboard.dart';
import '../home/tourist_dashboard.dart';
import '../vendor/vendor_dashboard.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (!authProvider.isInitialized || authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!authProvider.isAuthenticated) {
      return const LoginScreen();
    }

    switch (user?.role) {
      case 'admin':
        return const AdminDashboard();
      case 'vendor':
        return const VendorDashboard();
      case 'tourist':
      default:
        return const TouristDashboard();
    }
  }
}
